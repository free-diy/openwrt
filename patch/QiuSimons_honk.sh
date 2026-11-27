# --- 整合 QiuSimons/luci-app-daeuniverse 的宿主机编译环境依赖 ---
echo "🔧 正在搜索并配置 luci-app-daeuniverse 所需的宿主机工具链..."

# 1. 安装 Rust 环境及 cargo-zigbuild（如果尚未安装）
if ! command -v rustup &> /dev/null; then
  curl --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
fi
export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v cargo-zigbuild &> /dev/null; then
  cargo install --locked cargo-zigbuild
fi

# 2. 限定在 package 和 feeds 目录下快速精准搜索 honk_toolchain.sh
HONK_TOOLCHAIN_PATH=""
for candidate in \
  "package/luci-app-daeuniverse/honk/honk_toolchain.sh" \
  "package/luci-app-daeuniverse/honk_toolchain.sh" \
  "feeds/luci/applications/luci-app-daeuniverse/honk/honk_toolchain.sh"; do
  if [ -f "$candidate" ]; then
    HONK_TOOLCHAIN_PATH="$candidate"
    break
  fi
done

if [ -z "$HONK_TOOLCHAIN_PATH" ] && [ -d "package" ]; then
  HONK_TOOLCHAIN_PATH=$(find package -maxdepth 4 -type f -name "honk_toolchain.sh" | head -n 1)
fi

# 3. 执行脚本并解析版本
if [ -n "$HONK_TOOLCHAIN_PATH" ] && [ -f "$HONK_TOOLCHAIN_PATH" ]; then
  HONK_DIR=$(dirname "$HONK_TOOLCHAIN_PATH")
  HONK_PARENT_MAKEFILE="$HONK_DIR/../Makefile"
  echo "✅ 成功找到 honk 工具链脚本: $HONK_TOOLCHAIN_PATH"

  # 优先使用同级 Makefile；若不存在则尝试上一级 Makefile
  if [ -f "$HONK_DIR/Makefile" ]; then
    TOOLCHAIN_ENV=$(bash "$HONK_TOOLCHAIN_PATH" "$HONK_DIR/Makefile")
  elif [ -f "$HONK_PARENT_MAKEFILE" ]; then
    TOOLCHAIN_ENV=$(bash "$HONK_TOOLCHAIN_PATH" "$HONK_PARENT_MAKEFILE")
  else
    echo "❌ 错误: 未找到对应的 honk Makefile ($HONK_DIR/Makefile 或 $HONK_PARENT_MAKEFILE)" >&2
    exit 1
  fi

  echo "📋 解析到的工具链变量:"
  echo "$TOOLCHAIN_ENV"
  eval "$TOOLCHAIN_ENV"

  if [ -z "${BPF_LINKER_VERSION:-}" ] || [ -z "${BPF_LINKER_SHA256:-}" ]; then
    echo "❌ 错误: 未能从 honk_toolchain.sh 正确解析出 BPF_LINKER_VERSION 或 BPF_LINKER_SHA256" >&2
    exit 1
  fi

  # 安装 bpf-linker
  echo "📦 正在安装 bpf-linker v${BPF_LINKER_VERSION}..."
  curl --retry 3 --retry-delay 2 -fsSL -o /tmp/bpf-linker.tar.zst "https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
  echo "${BPF_LINKER_SHA256}  /tmp/bpf-linker.tar.zst" | sha256sum -c -
  sudo tar --zstd -xf /tmp/bpf-linker.tar.zst -C /usr/local/bin

  # 处理 ZIG_VERSION（脚本中默认返回 latest，需解析为具体版本号）
  RESOLVED_ZIG_VERSION="${ZIG_VERSION:-latest}"
  if [ "$RESOLVED_ZIG_VERSION" = "latest" ]; then
    RESOLVED_ZIG_VERSION=$(curl --retry 3 --retry-delay 2 -fsSL https://ziglang.org/download/index.json | python3 -c '
import sys, json
data = json.load(sys.stdin)
for k, v in data.items():
    if k != "master" and isinstance(v, dict) and "x86_64-linux" in v:
        print(k)
        break
' 2>/dev/null || true)
  fi

  if [ -n "$RESOLVED_ZIG_VERSION" ] && [ "$RESOLVED_ZIG_VERSION" != "latest" ]; then
    echo "📦 正在安装 Zig v${RESOLVED_ZIG_VERSION}..."
    curl --retry 3 --retry-delay 2 -fsSL -o /tmp/zig.tar.xz "https://ziglang.org/download/${RESOLVED_ZIG_VERSION}/zig-x86_64-linux-${RESOLVED_ZIG_VERSION}.tar.xz"
    sudo tar -xJf /tmp/zig.tar.xz -C /usr/local
    sudo ln -sf "/usr/local/zig-x86_64-linux-${RESOLVED_ZIG_VERSION}/zig" /usr/local/bin/zig
  else
    echo "⚠️ 未能自动解析具体 Zig 版本号，跳过手动下载 Zig 二进制包。"
  fi

  echo "✅ honk 专用宿主机工具链安装完成！"
else
  echo "⚠️ 指定目录未检测到 honk_toolchain.sh 脚本，跳过专用工具链安装。"
  exit 1
fi
# ---------------------------------------------
