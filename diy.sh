#!/bin/bash
# diy.sh — immortalwrt 云编译/本地定制脚本
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")" && pwd)}"
IWRT_DIR="$(pwd)"
PREPARE_ONLY=0
[ "${1:-}" = "--prepare" ] && PREPARE_ONLY=1

echo "==> REPO_DIR=$REPO_DIR"
echo "==> IWRT_DIR=$IWRT_DIR"

# 1) 追加 kenzok8/small-package feed
grep -q 'kenzok8/small-package' "$IWRT_DIR/feeds.conf.default" || \
  echo 'src-git smpackage https://github.com/kenzok8/small-package' >> "$IWRT_DIR/feeds.conf.default"

# 2) 克隆自定义包（放在 feeds install 之前，使本地包优先于 feed 同名包）
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2"; }
clone https://github.com/QiuSimons/luci-app-honk.git          package/honk
clone https://github.com/nikkinikki-org/OpenWrt-nikki.git    package/nikki
clone https://github.com/wkccd/quickfile.git                 package/quickfile
# openwrt-daede 固定到已验证的 df6a949 (2026.07.08)（最新版 2026.11.05 在 CI 上构建失败）
if [ ! -d package/openwrt-daede ]; then
  git clone https://github.com/kenzok8/openwrt-daede.git package/openwrt-daede
  git -C package/openwrt-daede checkout df6a949
fi
clone https://github.com/gdy666/luci-app-lucky.git           package/luci-app-lucky
clone https://github.com/sirpdboy/luci-app-adguardhome.git   package/luci-app-adguardhome

# 3) 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 4) 移除 feeds/luci 自带的 adguardhome
rm -rf feeds/luci/applications/luci-app-adguardhome

# 5) 覆盖 feeds 里的 UI 定制文件
cp -a "$REPO_DIR/custom/luci/."      feeds/luci/
cp -a "$REPO_DIR/custom/smpackage/." feeds/smpackage/

# 6) 覆盖自定义包内的菜单更名文件
cp "$REPO_DIR/custom/honk/luci-app-honk/po/zh_Hans/honk.po" \
   package/honk/luci-app-honk/po/zh_Hans/honk.po
# honk 预编译核心（上游仓库不含，缺失会导致 CI 尝试 Rust 现场编译而失败）
cp "$REPO_DIR/custom/honk/files/honk-core.bin"       package/honk/honk/files/honk-core.bin
cp "$REPO_DIR/custom/honk/files/honk-core.bin.stamp" package/honk/honk/files/honk-core.bin.stamp
cp "$REPO_DIR/custom/daede/luci-app-daede/root/usr/share/luci/menu.d/luci-app-daede.json" \
   package/openwrt-daede/luci-app-daede/root/usr/share/luci/menu.d/luci-app-daede.json

# 7) 默认 LAN IP 192.168.1.2
sed -i 's/"192\.168\.1\.1"/"192.168.1.2"/' \
  package/base-files/files/bin/config_generate

# 8) 复制 .config 与 files/ 覆盖
cp "$REPO_DIR/configs/x86-64.config" .config
rm -rf files
cp -a "$REPO_DIR/files" files

# 9) 编译
make defconfig
if [ "$PREPARE_ONLY" = 1 ]; then
  echo "==> 准备完成（--prepare），跳过编译"
  exit 0
fi
# 预置 daed/dae 源码（2026.07.08 已从 GitHub releases 下架）
mkdir -p dl
cp -f "$REPO_DIR/custom/daede/dl/"*.tar.gz dl/
ls -la dl/*.tar.gz 2>/dev/null | grep -E 'daed-src|dae-src' || echo "WARNING: daed/dae tarball 未就绪"
make download -j8
if ! make -j"$(nproc)"; then
  set +e
  echo "================= BUILD FAILED ================="
  exit 1
fi
