#!/system/bin/sh
# Device-side setup for phonectl (run as root from adb or Termux).
# Installs: termux-root-su (patched for KernelSU), Termux:API app,
# ADBKeyboard, and the termux-api clients into the Termux prefix.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
TP=${PREFIX:-/data/data/com.termux/files/usr}
export PREFIX="$TP"
export PATH="$TP/bin:/system/bin:/system/xbin"
export HOME=/data/data/com.termux/files/home
DISTRO=${PROOT_DISTRO:-ubuntu}
ROOTFS="$TP/var/lib/proot-distro/containers/$DISTRO/rootfs"
WORK=/data/local/tmp/phonectl-setup
mkdir -p "$WORK"

say() { echo "[setup] $*"; }

# ── 1. termux-root-su module (already patched for KernelSU) ────────────────
ZIP="$HERE/dist/termux-root-su-kernelsu.zip"
[ -f "$ZIP" ] || { echo "missing $ZIP"; exit 1; }
if [ -x /data/adb/ksu/bin/ksud ]; then
    /data/adb/ksu/bin/ksud module install "$ZIP"
elif command -v magisk >/dev/null 2>&1; then
    magisk --install-module "$ZIP"
else
    echo "no KernelSU/Magisk module installer found"; exit 1
fi
MOD=/data/adb/modules_update/termux-root-su
[ -d "$MOD" ] || MOD=/data/adb/modules/termux-root-su
if [ -d "$MOD" ]; then
    say "starting root proxy now"
    (sh "$MOD/service.sh" >/dev/null 2>&1 &)
fi

# ── 2. Termux:API app ──────────────────────────────────────────────────────
APK="$HERE/dist/termux-api.apk"
if [ ! -f "$APK" ] && [ -d "$ROOTFS" ]; then
    say "downloading Termux:API apk (via container curl)"
    URL='https://github.com/termux/termux-api/releases/download/v0.53.0/termux-api-app_v0.53.0%2Bgithub.debug.apk'
    proot-distro login "$DISTRO" -- bash -lc "curl -fsSL '$URL' -o /tmp/termux-api.apk" \
        && cp "$ROOTFS/tmp/termux-api.apk" "$APK" || true
fi
if [ -f "$APK" ]; then pm install -r "$APK" && say "Termux:API installed"; else
    say "Termux:API apk missing — install it manually from github.com/termux/termux-api/releases"
fi

# ── 3. ADBKeyboard (unicode input) ─────────────────────────────────────────
if [ -f "$HERE/dist/ADBKeyboard.apk" ]; then
    pm install -r "$HERE/dist/ADBKeyboard.apk" && say "ADBKeyboard installed"
fi

# ── 4. termux-api clients into $PREFIX ─────────────────────────────────────
DEB="$HERE/dist/termux-api_0.60.0_aarch64.deb"
if [ ! -f "$DEB" ] && [ -d "$ROOTFS" ]; then
    say "downloading termux-api client deb (TUNA mirror)"
    URL='https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main/pool/main/t/termux-api/termux-api_0.60.0_aarch64.deb'
    proot-distro login "$DISTRO" -- bash -lc "curl -fsSL '$URL' -o /tmp/termux-api.deb" \
        && cp "$ROOTFS/tmp/termux-api.deb" "$DEB" || true
fi
if [ -f "$DEB" ] && [ -d "$ROOTFS" ]; then
    cp "$DEB" "$ROOTFS/tmp/termux-api.deb"
    proot-distro login "$DISTRO" -- bash -lc \
        'rm -rf /tmp/tapideb && mkdir -p /tmp/tapideb && dpkg-deb -x /tmp/termux-api.deb /tmp/tapideb'
    SRC="$ROOTFS/tmp/tapideb/data/data/com.termux/files/usr"
    if [ -d "$SRC" ]; then
        cp -a "$SRC/bin/termux-"* "$TP/bin/"
        cp -a "$SRC/lib/libtermux-api.so" "$TP/lib/" 2>/dev/null || true
        mkdir -p "$TP/libexec" "$TP/include" "$TP/share/doc/termux-api"
        cp -a "$SRC/libexec/termux-api-broadcast" "$SRC/libexec/termux-callback" "$TP/libexec/" 2>/dev/null || true
        cp -a "$SRC/include/termux-api.h" "$TP/include/" 2>/dev/null || true
        cp -a "$SRC/share/doc/termux-api/copyright" "$TP/share/doc/termux-api/" 2>/dev/null || true
        ln -sf termux-api-broadcast "$TP/libexec/termux-api"
        TUID=$(stat -c %u /data/data/com.termux 2>/dev/null || echo 10009)
        chown -R "$TUID:$TUID" "$TP/bin" "$TP/libexec" 2>/dev/null || true
        chown "$TUID:$TUID" "$TP/lib/libtermux-api.so" 2>/dev/null || true
        chown -h "$TUID:$TUID" "$TP/libexec/termux-api" 2>/dev/null || true
        chmod 755 "$TP/bin/termux-"* "$TP/libexec/termux-"* 2>/dev/null || true
        say "termux-api clients installed"
    fi
fi

say "done. In the container run: bash install-container.sh"
say "verify: phonectl selftest"
