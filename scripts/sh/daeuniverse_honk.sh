##daeuniverse-dae/honk
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

  # --- 动态路径查找（活的）---
  src=""
  build_script=""
  for candidate in \
    "package/dae-packages/honk/src" \
    "package/honk/src" \
    "feeds/packages/net/honk/src"; do
    if [ -d "$candidate" ] && [ -f "$candidate/rust-toolchain.toml" ]; then
      src="$(realpath "$candidate")"
      parent_dir="$(dirname "$src")"
      if [ -f "$parent_dir/build.sh" ]; then
        build_script="$(realpath "$parent_dir/build.sh")"
        break
      fi
    fi
  done

  if [ -z "$src" ] && [ -d "package" ]; then
    found_path=$(find package -type f -name "rust-toolchain.toml" 2>/dev/null | grep -E 'honk/.*/rust-toolchain.toml' | head -n 1)
    if [ -n "$found_path" ]; then
      src="$(realpath "$(dirname "$found_path")")"
      parent_dir="$(dirname "$src")"
      if [ -f "$parent_dir/build.sh" ]; then
        build_script="$(realpath "$parent_dir/build.sh")"
      fi
    fi
  fi

  if [ -z "$src" ] || [ ! -d "$src" ] || [ -z "$build_script" ] || [ ! -f "$build_script" ]; then
    echo "❌ 错误: 无法动态定位到 honk 源码目录或 build.sh 脚本" >&2
    exit 1
  fi
  echo "✅ 成功动态定位到 honk 路径: $src"
  # -------------------------

  # The pinned bpf-linker checksum describes the x86_64 Linux host asset.
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo 'This script requires an x86_64 Linux build host' >&2; exit 1;
  }
  # Install every Rust userspace target declared by the OpenWrt honk recipe.
  # Several OpenWrt CPU variants can share the same Rust target.
  target_text="$(python3 - "$build_script" <<'PY_TARGETS'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
section = re.search(r'case[^\n]*HONK_ARCH_PACKAGES[^\n]*\bin\s*\n(.*?)\besac\b', text, re.S)
if section is None:
    sys.exit("Cannot locate the honk architecture mapping in build.sh")
targets = sorted(set(re.findall(r"\btarget\s*=\s*[\"']?([A-Za-z0-9_]+(?:-[A-Za-z0-9_.]+){2,})", section.group(1))))
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
  stable="$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["toolchain"]["channel"])' "$src/rust-toolchain.toml")"
  nightly="$(python3 -c 'import sys,tomllib;print(tomllib.load(open(sys.argv[1],"rb"))["toolchain"]["channel"])' "$src/crates/honk-ebpf/rust-toolchain.toml")"
  rustup toolchain install "$stable" --profile minimal --component rustfmt,clippy
  rustup target add --toolchain "$stable" "${targets[@]}"
  rustup toolchain install "$nightly" --profile minimal --component rust-src,llvm-tools
  # Same trusted pins file and same host binary as the upstream package workflow.
  source "$src/.github/ci/pins.env"
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
