# 自用openwrt
```bash
git clone -b openwrt-24.10 --single-branch --filter=blob:none https://github.com/immortalwrt/immortalwrt 24.10
```
cd
```bash
./scripts/feeds update -a
./scripts/feeds install -a
```
```bash
make menuconfig
```
make download -j8
make V=s -j1

二次
cd
git pull
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
make download -j8
make V=s -j$(nproc)

重新配置
rm -rf .config
make menuconfig
make V=s -j$(nproc)
