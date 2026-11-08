# immortalwrt-build

本地 ImmortalWrt 定制的「轻量构建仓库」，用于 GitHub Actions 云编译。immortalwrt 本体每次由 CI 拉取最新，本仓库只保存你的定制内容。

## 目录结构

- `configs/x86-64.config` — 完整 `.config`（x86/64 目标，默认 IP 192.168.1.2、argon 主题等）
- `files/` — 构建时复制进固件根目录的覆盖文件（nginx+quickfile 修复、apk/opkg 包管理后端）
- `custom/luci/` — 覆盖到 `feeds/luci/` 的已修改文件（passwall UI、vlmcsd/argon-config/daed 菜单名、collections 默认主题）
- `custom/smpackage/` — 覆盖到 `feeds/smpackage/` 的已修改文件（passwall2 UI）
- `custom/honk/`、`custom/daede/` — 自定义包内的菜单更名文件
- `diy.sh` — 一键定制脚本（本地/CI 通用）
- `.github/workflows/build.yml` — 云编译 workflow

## 本地编译

```bash
# 1. 克隆 immortalwrt
git clone --depth=1 https://github.com/immortalwrt/immortalwrt.git openwrt

# 2. 执行定制（--prepare 只做替换不编译，可用于验证）
cd openwrt && bash ../diy.sh          # 完整编译
# 或单线程：编辑 diy.sh 末尾 make -j1
```

## 云编译

推送本仓库到 GitHub 后：
- 手动：`Actions` → `Build ImmortalWrt` → `Run workflow`
- 自动：每周日定时构建
- 产物：Actions 的 Artifact；手动触发还会发布到 Release

## 更新插件/immortalwrt 版本

- immortalwrt 本体：改 `build.yml` 里的 `IWRT_BRANCH`（默认 master 跟随最新）
- 自定义包（honk/nikki/quickfile/daede/lucky/adguardhome）：`diy.sh` 里 `git clone` 跟随上游最新；如需固定版本，把 `--depth=1` 换成 `--depth=1 --branch <tag>`

## 更新定制文件

本地改完 immortalwrt 后，把改动文件按同样路径复制回本仓库对应目录（`custom/`、`files/`、`configs/`），提交即可，下次编译自动替换。

> 注：`custom/luci/applications/luci-app-daed/po/zh_Hans/daed.po`（daed→Daed）已备份，但当前 `.config` 未启用 `luci-app-daed`，该修改不生效；如需启用请自行勾选。
