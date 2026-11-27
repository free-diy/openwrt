#!/bin/bash

cat << 'EOF' > /tmp/git_sparse_clone
#!/bin/bash
# 增强版稀疏克隆命令 (参数1是分支名, 参数2是仓库地址, 参数3是子目录，多个目录空格分开)
branch=""
repourl=""
sub_paths=()
repodir=""

# 1. 智能参数解析
if [[ "$1" == http* ]]; then
  if [[ "$1" == *"tree/"* ]]; then
    repourl="${1%/tree/*}"
    rest="${1#*/tree/}"
    branch="${rest%%/*}"
    sub_paths=("${rest#*/}")
    echo ">> 检测到网页 URL，自动解析分支: [$branch], 路径: [${sub_paths[0]}]"
  else
    repourl="$1"
    branch="${2:-main}"
    shift 2
    sub_paths=("$@")
    echo ">> 检测到纯仓库地址，使用分支: [$branch]"
  fi
else
  branch="$1"
  repourl="$2"
  shift 2
  sub_paths=("$@")
  echo ">> 使用原始传参模式，分支: [$branch]"
fi

# 2. 准备克隆环境
repodir=$(basename "$repourl" .git)

# 3. 执行极速克隆
git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"
if [ $? -ne 0 ]; then
  echo "错误: 克隆失败，请检查 URL 或分支名。"
  exit 1
fi

cd "$repodir" || exit 1

# 4. 提取指定目录
if [ ${#sub_paths[@]} -eq 0 ]; then
  echo ">> 未指定子路径，拉取全量代码..."
  git sparse-checkout disable
else
  echo ">> 正在提取指定目录: ${sub_paths[*]}"
  git sparse-checkout set "${sub_paths[@]}"
fi

# 5. 搬运到 ../package/
mkdir -p ../package/
for sub in "${sub_paths[@]}"; do
  if [ -d "$sub" ]; then
    target_name=$(basename "$sub")
    target="../package/$target_name"
    [ -d "$target" ] && rm -rf "$target"
    mv -f "$sub" ../package/
    echo "   [已完成] $target_name"
  fi
done

# 6. 清理
cd .. && rm -rf "$repodir"
echo ">> 任务结束。"
EOF

sudo install -m 0755 /tmp/git_sparse_clone /usr/local/bin/git_sparse_clone
rm -f /tmp/git_sparse_clone
echo "✅ 已将 git_sparse_clone 注册为全局系统命令 (/usr/local/bin/git_sparse_clone)"
