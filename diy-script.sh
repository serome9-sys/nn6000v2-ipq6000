
#!/bin/bash

# =====================================================================
# 1. 基础清理：移除可能与第三方源冲突的官方残留包
# =====================================================================
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-serverchan

# =====================================================================
# 2. 核心步骤：追加 kenzok8/small-package 核心第三方软件源
# =====================================================================
# 这一步能让编译系统完美抓取 passwall, openclash, aliddns, syncdial 等插件
echo 'src-git kenzo https://github.com/kenzok8/small-package' >> feeds.conf.default

# =====================================================================
# 3. 稀疏克隆辅助函数（保持原脚本优秀特性，用于抓取零散单包）
# =====================================================================
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# =====================================================================
# 4. 精准引入您点名索要的非默认插件与必备依赖
# =====================================================================
# 单线多拨与多线负载均衡控制台所需依赖
git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite

# 经典且对 23.05 适配极佳的 Argon 漂亮主题及其配置后台
git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# =====================================================================
# 5. 针对 23.05 稳定版分支及内核进行细节调整与修复
# =====================================================================
# 核心修复：修复编译部分第三方 Go 语言插件（如较新版 OpenClash / Passwall 依赖）时的底层路径报错
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 修改后台本地时间显示格式（让主页看起来更直观美观）
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm 2>/dev/null || true

#2026.5.29 添加后台地址  对IPV6进行限制
sed -i 's/192.168.1.1/192.168.123.200/g' package/base-files/files/bin/config_generate
sed -i 's/auto/disabled/g' package/base-files/files/lib/netifd/proto/dhcpv6.sh

# 终极绝杀：直接在脚本里强行将无线 wpad 组件从配置中剔除，阻断编译死锁
echo "CONFIG_PACKAGE_wpad-openssl=n" >> .config
echo "CONFIG_PACKAGE_wpad-basic-openssl=n" >> .config
echo "CONFIG_PACKAGE_wpad-full-openssl=n" >> .config
echo "CONFIG_PACKAGE_hostapd-common=n" >> .config


# 取消主题默认强制覆盖行为，保证系统主题切换不会产生后台死锁
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \; 2>/dev/null || true

# =====================================================================
# 6. 核心馈源更新与合并（必须放在最后）
# =====================================================================
./scripts/feeds update -a
./scripts/feeds install -a
