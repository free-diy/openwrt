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
  # Install every Rust userspace target declared by the OpenWrt honk recipe.
  # Several OpenWrt CPU variants can share the same Rust target.
  target_text="$(python3 - package/dae-packages/honk/build.sh <<'PY_TARGETS'
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
  # Keep rustup away from $HOME/.cargo and from OpenWrt's dl/cargo.
  export CARGO_HOME="${HOME}/.honk-cargo"
  export RUSTUP_HOME="${HOME}/.honk-rustup"
  export PATH="$CARGO_HOME/bin:$PATH"
  unset RUSTUP_TOOLCHAIN || true
  if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
    curl --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none --no-modify-path
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
  # Only bpf-linker may be visible to later steps. Never export rustc/cargo/rustup.
  linker_dir="${HOME}/.honk-bin"
  mkdir -p "$linker_dir"
  install -m 0755 "$CARGO_HOME/bin/bpf-linker" "$linker_dir/bpf-linker"
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    printf '%s\n' "$linker_dir" >> "$GITHUB_PATH"
  fi
)
honk_rust_status=$?
if [ "$honk_rust_status" -ne 0 ]; then
  echo "honk Rust environment preparation failed" >&2
  exit "$honk_rust_status"
fi
##End of dae/honk
