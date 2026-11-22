##dae/honk
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/luci/applications/luci-app-honk
rm -rf feeds/packages/net/dae
rm -rf feeds/packages/net/honk
if [ -d "package/dae-packages" ]; then
  git -C package/dae-packages pull
  git -C package/dae-packages/dae/src pull
  git -C package/dae-packages/honk/src pull
else
  git clone https://github.com/daeuniverse/openwrt-packages package/dae-packages
  git clone --recurse-submodules https://github.com/daeuniverse/dae package/dae-packages/dae/src
  git clone --recurse-submodules https://github.com/daeuniverse/honk package/dae-packages/honk/src
fi
# Prepare host Rust from the checked-out honk source requirements.
# Isolate strict error handling and upstream pins from the rest of this script.
(
  set -euo pipefail
  src="$(realpath package/dae-packages/honk/src)"
  # The pinned bpf-linker checksum describes the x86_64 Linux host asset.
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo 'This script requires an x86_64 Linux build host' >&2; exit 1;
  }
  # 动态查找 build.sh（优先默认路径，找不到再搜索）
  honk_build_sh="package/dae-packages/honk/build.sh"
  if [ ! -f "$honk_build_sh" ]; then
    honk_build_sh="$(find package/dae-packages "$src" -maxdepth 4 -type f -name "build.sh" 2>/dev/null | head -n1 || true)"
  fi
  [ -f "$honk_build_sh" ] || {
    echo "Cannot locate honk build.sh" >&2; exit 1;
  }
  # Install every Rust userspace target declared by the OpenWrt honk recipe.
  # Several OpenWrt CPU variants can share the same Rust target.
  target_text="$(python3 - "$honk_build_sh" <<'PY_TARGETS'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
section = re.search(r'case[^\n]*HONK_ARCH_PACKAGES[^\n]*\bin\s*\n(.*?)\besac\b', text, re.S)
scope = section.group(1) if section else text
targets = sorted(set(re.findall(r"\b(?:rust_)?target\s*=\s*[\"']?([A-Za-z0-9_]+(?:-[A-Za-z0-9_.]+){2,})", scope)))
if not targets:
    targets = sorted(set(re.findall(r"\b([a-z0-9_]+-(?:unknown|pc|apple|linux)-(?:gnu|musl|gnueabihf|musleabihf|android))\b", scope)))
if not targets:
    sys.exit("No literal Rust targets found; review the upstream honk architecture mapping")
print("\n".join(targets))
PY_TARGETS
  )"
  mapfile -t targets <<< "$target_text"
  printf 'Preparing honk Rust target: %s\n' "${targets[@]}"
  # Must run as the same ordinary user that runs OpenWrt make.
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  export PATH="$CARGO_HOME/bin:$PATH"
  if ! command -v rustup >/dev/null 2>&1; then
    installer="$(mktemp)"
    curl --proto '=https' --tlsv1.2 -fLsS --retry 3 https://sh.rustup.rs -o "$installer"
    sh "$installer" -y --profile minimal --default-toolchain none --no-modify-path
    rm -f "$installer"
  fi
  # 动态查找 stable 与 nightly 的 rust-toolchain.toml
  stable_toml="$src/rust-toolchain.toml"
  [ -f "$stable_toml" ] || stable_toml="$(find "$src" -maxdepth 3 -type f -name "rust-toolchain.toml" ! -path "*ebpf*" 2>/dev/null | head -n1 || true)"
  nightly_toml="$src/crates/honk-ebpf/rust-toolchain.toml"
  [ -f "$nightly_toml" ] || nightly_toml="$(find "$src" -maxdepth 4 -type f -name "rust-toolchain.toml" -path "*ebpf*" 2>/dev/null | head -n1 || true)"
  stable="$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["toolchain"]["channel"])' "$stable_toml")"
  nightly="$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["toolchain"]["channel"])' "$nightly_toml")"
  rustup toolchain install "$stable" --profile minimal --component rustfmt,clippy
  rustup target add --toolchain "$stable" "${targets[@]}"
  rustup toolchain install "$nightly" --profile minimal --component rust-src,llvm-tools
  # 动态查找 pins.env（优先默认路径，找不到再搜索）
  pins_file="$src/.github/ci/pins.env"
  if [ ! -f "$pins_file" ]; then
    pins_file="$(find package/dae-packages "$src" -maxdepth 4 -type f -name "pins.env" 2>/dev/null | head -n1 || true)"
  fi
  # Same trusted pins file and same host binary as the upstream package workflow.
  source "$pins_file"
  archive="$(mktemp --suffix=.tar.zst)"
  curl -fLsS --retry 3 -o "$archive" \
    "https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
  printf '%s  %s\n' "$BPF_LINKER_SHA256" "$archive" | sha256sum -c -
  mkdir -p "$CARGO_HOME/bin"
  tar --zstd -xf "$archive" -C "$CARGO_HOME/bin"
  rm -f "$archive"
  (cd "$src"; cargo --version; rustc --version; bpf-linker --version)
  rustup target list --installed --toolchain "$stable"
  # GitHub Actions starts a new shell for every step.
  if [[ -n "${GITHUB_ENV:-}" && -n "${GITHUB_PATH:-}" ]]; then
    printf 'CARGO_HOME=%s\nRUSTUP_HOME=%s\n' "$CARGO_HOME" "$RUSTUP_HOME" >> "$GITHUB_ENV"
    printf '%s\n' "$CARGO_HOME/bin" >> "$GITHUB_PATH"
  fi
)
honk_rust_status=$?
if [ "$honk_rust_status" -ne 0 ]; then
  echo "honk Rust environment preparation failed" >&2
  exit "$honk_rust_status"
fi
##End of dae/honk
