#!/bin/bash

cat << 'EOF' > /tmp/git_sparse_clone
#!/bin/bash
# 增强版稀疏克隆函数 (参数1是分支名, 参数2是仓库地址, 参数3是子目录，同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开)
function git_sparse_clone() {
  local branch=""
  local repourl=""
  local sub_paths=()
  local repodir=""

  # 1. 智能参数解析
  if [[ "$1" == http* ]]; then
    # 情况 A: 第一个参数是 URL (可能是网页链接或纯仓库地址)
    if [[ "$1" == *"tree/"* ]]; then
      # 自动解析 GitHub 网页格式: .../tree/分支/路径
      repourl="${1%/tree/*}"
      local rest="${1#*/tree/}"
      branch="${rest%%/*}"
      sub_paths=("${rest#*/}")
      echo ">> 检测到网页 URL，自动解析分支: [$branch], 路径: [${sub_paths[0]}]"
    else
      # 纯仓库地址，尝试使用第二个参数作为分支，默认为 main
      repourl="$1"
      branch="${2:-main}"
      shift 2
      sub_paths=("$@")
      echo ">> 检测到纯仓库地址，使用分支: [$branch]"
    fi
  else
    # 情况 B: 兼容你原始的代码格式 (参数1:分支 参数2:地址 参数3+:路径)
    branch="$1"
    repourl="$2"
    shift 2
    sub_paths=("$@")
    echo ">> 使用原始传参模式，分支: [$branch]"
  fi

  # 2. 准备克隆环境
  # 使用 basename 处理 .git 后缀，防止 cd 失败
  repodir=$(basename "$repourl" .git)
  
  # 3. 执行极速克隆 (Blob 过滤 + 稀疏模式)
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"
  if [ $? -ne 0 ]; then
    echo "错误: 克隆失败，请检查 URL 或分支名。"
    return 1
  fi

  cd "$repodir" || return

  # 4. 如果没有指定子路径，默认拉取整个仓库内容
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
      local target_name=$(basename "$sub")
      local target="../package/$target_name"
      [ -d "$target" ] && rm -rf "$target"
      mv -f "$sub" ../package/
      echo "   [已完成] $target_name"
    fi
  done

  # 6. 清理
  cd .. && rm -rf "$repodir"
  echo ">> 任务结束。"
}

git_sparse_clone "$@"
EOF

sudo install -m 0755 /tmp/git_sparse_clone /usr/local/bin/git_sparse_clone
rm -f /tmp/git_sparse_clone
echo "✅ 已生成全局命令: /usr/local/bin/git_sparse_clone"

# 增强版稀疏克隆end
