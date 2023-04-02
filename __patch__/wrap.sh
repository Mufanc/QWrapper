#!/usr/bin/sh
if [ "$1" = "--wrap" ] ; then
    mkdir -p $HOME/.config/QQ
    exec bwrap --unshare-all --share-net \
        --dev-bind / / \
        --proc /proc \
        --ro-bind "$HOME" "$HOME" \
        --bind "$HOME/Downloads" "$HOME/Downloads" \
        --tmpfs "$HOME/.config" \
        --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
        --setenv LD_PRELOAD /opt/QQ/__patch__/libhook.so \
        --tmpfs /opt/QQ/resources/app/sharp-lib \
        --chdir "$HOME" \
        /opt/QQ/qq
else
    /opt/QQ/__patch__/daemon "$0"
fi
