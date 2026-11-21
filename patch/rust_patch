# rust补丁
rust_mk="feeds/packages/lang/rust/Makefile"
if [ ! -f "$rust_mk" ]; then
  echo "missing $rust_mk" >&2
  exit 1
fi

if grep -q -- '--set=llvm.download-ci-llvm=true' "$rust_mk"; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' "$rust_mk"
elif grep -q -- 'llvm\.download-ci-llvm' "$rust_mk"; then
  sed -i -E 's/(llvm\.download-ci-llvm\s*=\s*)true/\1false/g' "$rust_mk"
else
  echo "info: llvm.download-ci-llvm not found in $rust_mk, skip patching"
fi

if grep -q -- 'download-ci-llvm' "$rust_mk"; then
  grep -n -- 'download-ci-llvm' "$rust_mk" || true
  if grep -q -- '--set=llvm.download-ci-llvm=true' "$rust_mk"; then
    echo "failed to disable download-ci-llvm" >&2
    exit 1
  fi
fi

# 补齐通用 host 与 target 路径，避免残留旧构建产物或状态戳导致跳过重编
rm -rf \
  build_dir/host/rustc-* \
  build_dir/target-*/host/rustc-* \
  staging_dir/host/stamp/.rust_installed \
  staging_dir/target-*/stamp/.rust_installed
# rust补丁 end
