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

if [ -d "$LITELOADER" ]; then                                                # 支持 LiteLoaderQQNT
    profile="$HOME/.config/LiteLoaderQQNT"                                   # 修改配置目录
    mkdir -p "$profile"
    args="$args --bind $profile $profile"
    args="$args --setenv LITELOADERQQNT_PROFILE $profile"

    entry="$BASE/resources/app/package.json"
    fake_entry=$(mktemp)
    sed 's#./app_launcher/index.js#../LiteLoader#' "$entry" > "$fake_entry"  # 替换入口点

    args="$args --tmpfs $BASE/resources"                                     # 需要挂 tmpfs 否则下步无权创建文件夹
    args="$args --bind $BASE/resources/app $BASE/resources/app"              # 挂回 app 目录
    args="$args --bind $LITELOADER $BASE/resources/LiteLoader"               # 挂载插件目录
    args="$args --bind $fake_entry $entry"                                   # 挂载假入口
fi

args="$args --chdir $HOME $BASE/main"                                        # 启动主程序

# shellcheck disable=SC2086
exec bwrap $args
