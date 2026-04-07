#!/usr/bin/env sh

set -eu

BASE="/opt/QQ"
LITELOADER="$HOME/.config/QQ/LiteLoaderQQNT"
UID_NUM="$(id -u)"
GID_NUM="$(id -g)"
XAUTH_FILE="${XAUTHORITY:-$HOME/.Xauthority}"

mkdir -p "$HOME/.config/QQ"
mkdir -p "$HOME/Downloads"

args=""

# ===== Namespace =====
args="$args --unshare-all --share-net"
args="$args --die-with-parent"
args="$args --new-session"
args="$args --proc /proc"

# ===== Devices =====
args="$args --dev /dev"
if [ -d /dev/dri ]; then
    args="$args --dev-bind /dev/dri /dev/dri"
fi

# ===== Runtime dirs =====
args="$args --tmpfs /tmp"
args="$args --dir /run"
args="$args --dir /run/user"
args="$args --dir /run/user/$UID_NUM"

# ===== Minimal system view =====
args="$args --ro-bind /usr /usr"
args="$args --ro-bind /lib /lib"
if [ -d /lib64 ]; then
    args="$args --ro-bind /lib64 /lib64"
fi
args="$args --ro-bind /bin /bin"
if [ -d /sbin ]; then
    args="$args --ro-bind /sbin /sbin"
fi
args="$args --ro-bind /etc /etc"
args="$args --ro-bind $BASE $BASE"

# ===== HOME isolation =====
# 不再暴露整个真实 HOME，只给一个临时 HOME，然后精确放行
args="$args --tmpfs $HOME"
args="$args --dir $HOME/.config"
args="$args --dir $HOME/Downloads"

# QQ 配置持久化
args="$args --bind $HOME/.config/QQ $HOME/.config/QQ"

# 下载目录持久化
args="$args --bind $HOME/Downloads $HOME/Downloads"

# 临时缓存
args="$args --tmpfs $HOME/.cache"

# crash 目录临时化
args="$args --tmpfs $HOME/.config/QQ/crash_files"

# ===== X11 =====
if [ -n "${DISPLAY:-}" ]; then
    args="$args --setenv DISPLAY $DISPLAY"
    if [ -d /tmp/.X11-unix ]; then
        args="$args --ro-bind /tmp/.X11-unix /tmp/.X11-unix"
    fi
fi

if [ -f "$XAUTH_FILE" ]; then
    args="$args --ro-bind $XAUTH_FILE $XAUTH_FILE"
    args="$args --setenv XAUTHORITY $XAUTH_FILE"
fi

# ===== Wayland =====
args="$args --setenv XDG_RUNTIME_DIR /run/user/$UID_NUM"
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "/run/user/$UID_NUM/$WAYLAND_DISPLAY" ]; then
    args="$args --bind /run/user/$UID_NUM/$WAYLAND_DISPLAY /run/user/$UID_NUM/$WAYLAND_DISPLAY"
    args="$args --setenv WAYLAND_DISPLAY $WAYLAND_DISPLAY"
fi

# ===== D-Bus =====
if [ -S "/run/user/$UID_NUM/bus" ]; then
    args="$args --bind /run/user/$UID_NUM/bus /run/user/$UID_NUM/bus"
    args="$args --setenv DBUS_SESSION_BUS_ADDRESS unix:path=/run/user/$UID_NUM/bus"
fi

if [ -S /run/dbus/system_bus_socket ]; then
    args="$args --ro-bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket"
fi

# ===== Common env =====
args="$args --setenv HOME $HOME"
args="$args --setenv USER ${USER:-$(id -un)}"
args="$args --setenv LOGNAME ${LOGNAME:-$(id -un)}"
args="$args --setenv SHELL ${SHELL:-/bin/sh}"
args="$args --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
args="$args --setenv XDG_CONFIG_HOME $HOME/.config"
args="$args --setenv XDG_CACHE_HOME $HOME/.cache"
args="$args --setenv XDG_DOWNLOAD_DIR $HOME/Downloads"

# ===== GPU/Mesa compatibility =====
# 某些 Electron/Chromium 程序会参考这些环境
if [ -d /usr/share/drirc.d ]; then
    args="$args --ro-bind /usr/share/drirc.d /usr/share/drirc.d"
fi
if [ -d /usr/share/glvnd ]; then
    args="$args --ro-bind /usr/share/glvnd /usr/share/glvnd"
fi

# ===== LD_PRELOAD inject =====
if [ -n "${DEBUG:-}" ]; then
    inject="$(realpath "$(dirname "$0")")/inject/target/debug/libinject.so"
    args="$args --setenv LD_PRELOAD $inject"
else
    args="$args --setenv LD_PRELOAD $BASE/libinject.so"
fi

# ===== LiteLoader =====
if [ -d "$LITELOADER" ]; then
    echo "Loading LiteLoaderQQNT..."

    # 挂载 LiteLoaderQQNT 目录
    mkdir -p "$LITELOADER"
    args="$args --bind $LITELOADER $LITELOADER"

    # 挂载 package.json
    fake_package="$(mktemp)"
    package_json="$BASE/resources/app/package.json"
    sed -e 's/index.js/loader_index.js/g' \
        -e 's/application.asar/./g' \
        "$package_json" > "$fake_package"
    args="$args --ro-bind $fake_package $package_json"

    # 挂载入口 js
    overlay_dir="$BASE/resources/app/app_launcher"
    args="$args --tmpfs $overlay_dir"
    for file in "$overlay_dir"/*; do
        [ -e "$file" ] || continue
        args="$args --bind $file $file"
    done

    fake_entry="$(mktemp)"
    printf "require('%s');\n" "$LITELOADER" > "$fake_entry"
    args="$args --ro-bind $fake_entry $BASE/resources/app/app_launcher/loader_index.js"
fi

# ===== Workdir / launch =====
args="$args --chdir $HOME"

# shellcheck disable=SC2086
exec bwrap $args "$BASE/main"