#!/usr/bin/env sh

BASE="/opt/QQ"
LITELOADER="$HOME/.config/QQ/LiteLoaderQQNT"

mkdir -p "$HOME/.config/QQ"

args=""
args="$args --unshare-all --share-net"                                       # 分离命名空间（主要是 /proc 隔离）
args="$args --dev-bind / /"                                                  # 挂载根目录
args="$args --proc /proc"                                                    # 挂载 /proc
args="$args --ro-bind $HOME $HOME"                                           # 家目录只读
args="$args --bind $HOME/Downloads $HOME/Downloads"                          # 允许写入下载目录
args="$args --tmpfs $HOME/.config --bind $HOME/.config/QQ $HOME/.config/QQ"  # 隔离配置目录
args="$args --tmpfs $HOME/.config/QQ/crash_files"                            # 解决 libvips 导致的 crash

if [ -n "$DEBUG" ]; then
    inject="$(realpath "$(dirname "$0")")/inject/target/debug/libinject.so"
    args="$args --setenv LD_PRELOAD $inject"
else
    args="$args --setenv LD_PRELOAD $BASE/libinject.so"
fi

if [ -d "$LITELOADER" ]; then
    echo "Loading LiteLoaderQQNT..."

    # 挂载 LiteLoaderQQNT 目录
    mkdir -p "$LITELOADER"
    args="$args --bind $LITELOADER $LITELOADER"

    # 挂载 package.json
    fake_package=$(mktemp)
    package_json="$BASE/resources/app/package.json"
    sed -e 's/index.js/loader_index.js/g' -e 's/application.asar/./g' "$package_json" > "$fake_package"
    args="$args --ro-bind $fake_package $package_json"

    # 挂载入口 js
    overlay_dir="$BASE/resources/app/app_launcher"
    args="$args --tmpfs $overlay_dir"
    for file in "$overlay_dir"/*; do
        args="$args --bind $file $file" 
    done
    fake_entry=$(mktemp)
    echo "require('$LITELOADER');" > "$fake_entry"
    args="$args --ro-bind $fake_entry $BASE/resources/app/app_launcher/loader_index.js"
fi

args="$args --chdir $HOME $BASE/main"

# shellcheck disable=SC2086
exec bwrap $args
