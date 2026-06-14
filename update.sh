#!/usr/bin/env bash

# download-link:
#   window: https://dln1.ncdn.ec/general-files/soft/desktop/Z-Library-latest.exe
#   darwin: https://dln1.ncdn.ec/general-files/soft/desktop/zlibrary-setup-latest.dmg
#   linux: https://dln1.ncdn.ec/general-files/soft/desktop/Z-Library_3.1.0_amd64.deb
#
set -euo pipefail

# Z-Library 专用更新脚本
# 用法: ./update.sh
# 功能: 自动探测最新版本（通过 latest 重定向），计算 NAR hash，重写 sources.nix

cd "$(dirname "$0")"

# 官方下载基础 URL（提供 latest 重定向）
LATEST_URL="https://dln1.ncdn.ec/general-files/soft/desktop/Z-Library-latest-amd64.deb"
echo "==> 正在探测最新版本: ${LATEST_URL}"

# 获取真实下载 URL（跟随重定向）
REAL_URL=$(curl -sSL -o /dev/null -w '%{url_effective}' "$LATEST_URL" 2>/dev/null || true)

if [[ -z "$REAL_URL" ]]; then
  echo "ERROR: 无法从 latest 链接获取真实地址，请手动设置 VERSION 和 URL"
  echo "示例: VERSION=3.1.0 URL=https://... ./update.sh"
  if [[ -n "${VERSION:-}" && -n "${URL:-}" ]]; then
    REAL_URL="$URL"
    VERSION="$VERSION"
    echo "使用手动指定版本: $VERSION, URL: $REAL_URL"
  else
    exit 1
  fi
else
  # 从真实 URL 中提取版本号，例如 Z-Library_3.1.0_amd64.deb -> 3.1.0
  VERSION=$(echo "$REAL_URL" | grep -oP 'Z-Library_\K[\d\.]+(?=_amd64\.deb)')
  if [[ -z "$VERSION" ]]; then
    echo "ERROR: 无法从 URL 中提取版本号: $REAL_URL"
    exit 1
  fi
fi

echo "==> 最新版本: $VERSION"
echo "==> 下载地址: $REAL_URL"

# 计算 nix 的 base32 哈希 (与 fetchurl 兼容)
echo "==> 正在下载并计算 sha256 (nix hash)..."
HASH=$(nix-prefetch-url "$REAL_URL" 2>/dev/null | tail -n1)
echo "==> sha256: $HASH"

# 生成 sources.nix
cat >sources.nix <<EOF
{
  x86_64-linux = {
    version = "$VERSION";
    url = "$REAL_URL";
    sha256 = "$HASH";
  };
}
EOF

echo "==> sources.nix 已更新 (版本 $VERSION)"

# 可选：本地构建验证
# echo "==> 尝试构建..."
# nix build .# -L
