# 🛡️ 使用 Python 强力修补 rust 的 Makefile
RUST_MAKEFILE="feeds/packages/lang/rust/Makefile"
if [ -f "$RUST_MAKEFILE" ]; then
  echo "🔧 正在使用 Python 深度修补 $RUST_MAKEFILE..."
  python3 - << 'EOF'
import os

path = "feeds/packages/lang/rust/Makefile"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 检查是否已经修改过
    if "download-ci-llvm = false" in content:
        print("⚠️ Makefile 中已包含 download-ci-llvm = false，跳过。")
    else:
        # 寻找 Makefile 中生成 bootstrap.toml 的常见写入点并注入配置
        # 兼容 sbwml 仓库中通过 cat 或 printf 写入 bootstrap.toml 的逻辑
        if "bootstrap.toml" in content:
            # 在创建/写入 bootstrap.toml 的命令后追加 [llvm] 节和 download-ci-llvm = false
            # 通过向 Makefile 注入 shell 追加命令，确保生成时写入该配置
            target_str = "bootstrap.toml"
            pos = content.rfind(target_str)
            end_of_line = content.find("\n", pos)
            
            if end_of_line != -1:
                # 注入追加写入命令
                patch_snippet = '\n\t@echo -e "\\n[llvm]\\ndownload-ci-llvm = false" >> bootstrap.toml\n'
                new_content = content[:end_of_line+1] + patch_snippet + content[end_of_line+1:]
                
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print("✅ 成功向 feeds/packages/lang/rust/Makefile 注入关闭 CI LLVM 的补丁！")
            else:
                print("❌ 定位行尾失败。")
        else:
            print("❌ 未能在 Makefile 中找到 bootstrap.toml 关键字。")
EOF
else
  echo "⚠️ 警告: 未找到 $RUST_MAKEFILE 文件，请确认是否已执行 feeds install！"
fi
