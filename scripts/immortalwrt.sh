#!/bin/bash

# 1. 修改默认 IP
sed -i '/lan)/s/192\.168\.[0-9.]*/192.168.100.253/' package/base-files/files/bin/config_generate

# 2.移除要替换的包
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/packages/net/dae
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/packages/net/daed
#rm -rf feeds/packages/lang/golang
rm -rf feeds/packages/lang/rust
#rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
#rm -rf feeds/luci/applications/luci-app-netdata

# 3. 调用 clone.sh，并自动清理 Windows 换行符
BUILD_PATH="$GITHUB_WORKSPACE/patch/clone.sh"
if [ -f "$BUILD_PATH" ]; then
  echo "🧹 正在自动清理 clone.sh 的 Windows 换行符 (CRLF -> LF)..."
  sed -i 's/\r$//' "$BUILD_PATH"
  
  echo "🔑 正在赋予 clone.sh 执行权限..."
  chmod +x "$BUILD_PATH"
  
  echo "🚀 正在执行 clone.sh..."
  bash "$BUILD_PATH"
fi
###########################################

# 4. 更新 golang 和 rust
#git clone --depth=1 -b 27.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_rust feeds/packages/lang/rust

# 5. 主题与常规插件
# 添加argon主题
#git clone --depth=1 -b master https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
#git clone --depth=1 -b master https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
# 添加Lucky
#git clone --depth=1 -b main https://github.com/gdy666/luci-app-lucky package/lucky
# 添加系统高级设置
#git clone --depth=1 -b main https://github.com/free-diy/luci-app-advancedplus package/luci-app-advancedplus
# 添加kenzok8大鹅
#git clone --depth=1 -b main https://github.com/kenzok8/openwrt-daede package/openwrt-daede
# 添加QiuSimons大鹅
#git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed package/openwrt-daed
# 添加Passwall 及其依赖
#git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
#git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
#git clone --depth=1 -b main https://github.com/Openwrt-Passwall/openwrt-passwall2 package/passwall12-luci
# 添加ssrplus
#git clone --depth=1 -b dev https://github.com/fw876/helloworld.git package/helloworld
# 添加中文版netdata
#git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
# 添加应用管理
#git clone --depth=1 -b master https://github.com/destan19/OpenAppFilter package/OpenAppFilter
# 添加momo
#git clone --depth=1 -b main https://github.com/nikkinikki-org/OpenWrt-momo package/OpenWrt-momo
# 添加壁虎合集
#git clone --depth=1 -b main https://github.com/free-diy/all-proxy package/all-proxy
# 添加nikki
#git clone --depth=1 -b main https://github.com/nikkinikki-org/OpenWrt-nikki package/OpenWrt-nikki
#git_sparse_clone main https://github.com/nikkinikki-org/OpenWrt-nikki luci-app-nikki mihomo-meta nikki
# 添加openclash
#git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash
# 添加taskplan定时设置插件
#git_sparse_clone main https://github.com/sirpdboy/luci-app-taskplan luci-app-taskplan
# 添加设备关机功能
git_sparse_clone master https://github.com/sirpdboy/luci-app-poweroffdevice luci-app-poweroffdevice
# 添加istore
#git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
#git_sparse_clone main https://github.com/linkease/istore luci
# 特别注意：iStore 的目录在仓库里叫 luci，移动到 package 后我们给它改个名防止冲突
#[ -d package/luci ] && mv package/luci package/luci-app-istore

# 添加rtp2httpd
#git_sparse_clone https://github.com/stackia/rtp2httpd/tree/main/openwrt-support/luci-app-rtp2httpd
#git_sparse_clone https://github.com/stackia/rtp2httpd/tree/main/openwrt-support/rtp2httpd

# 6. 修复与优化编译环境
# 禁用 Rust 的 LLVM 编译，节省 10GB+ 空间和大量时间
#if [ -f feeds/packages/lang/rust/Makefile ]; then
#    sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
#fi

# 7. 其他
# 专门针对 advancedplus 的流氓逻辑进行清洗
#if [ -f package/luci-app-advancedplus/root/etc/init.d/advancedplus ]; then
#    sed -i '/zsh/d' package/luci-app-advancedplus/root/etc/init.d/advancedplus
#fi

# 8. 删除多余的插件
#rm -rf package/all-proxy/mihomo
#rm -rf package/helloworld/mihomo
