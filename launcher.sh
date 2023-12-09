#!/usr/bin/env sh

LITELOADER="$HOME/.config/QQ/LiteLoaderQQNT"

mkdir -p $HOME/.config/QQ
killall -9 /opt/QQ/main 2>/dev/null

args=""
args="$args --unshare-all --share-net"                                       # 分离命名空间（主要是 /proc 隔离）
args="$args --dev-bind / /"                                                  # 挂载根目录
args="$args --proc /proc"                                                    # 挂载 /proc
args="$args --ro-bind $HOME $HOME"                                           # 家目录只读
args="$args --bind $HOME/Downloads $HOME/Downloads"                          # 允许写入下载目录
args="$args --tmpfs $HOME/.config --bind $HOME/.config/QQ $HOME/.config/QQ"  # 隔离配置目录
args="$args --tmpfs $HOME/.config/QQ/crash_files"                            # 解决 libvips 导致的 crash

if [ -d "$LITELOADER" ]; then                                                # 支持 LiteLoaderQQNT
    profile="$HOME/.config/LiteLoaderQQNT"                                   # 修改配置目录
    mkdir -p "$profile"
    args="$args --bind $profile $profile"
    args="$args --setenv LITELOADERQQNT_PROFILE $profile"

    entry=/opt/QQ/resources/app/package.json
    fake_entry=$(mktemp)
    sed 's#./app_launcher/index.js#../LiteLoader#' "$entry" > $fake_entry    # 替换入口点

    args="$args --tmpfs /opt/QQ/resources"                                   # 需要挂 tmpfs 否则下步无权创建文件夹
    args="$args --bind /opt/QQ/resources/app /opt/QQ/resources/app"          # 挂回 app 目录
    args="$args --bind $LITELOADER /opt/QQ/resources/LiteLoader"             # 挂载插件目录
    args="$args --bind $fake_entry $entry"                                   # 挂载假入口
fi

args="$args --chdir $HOME /opt/QQ/main"                                      # 启动主程序

exec bwrap $args
