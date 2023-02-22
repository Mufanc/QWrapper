#!/usr/bin/sh
if [ "$1" = "--wrap" ] ; then
    exec bwrap --unshare-all --share-net \
    --dev-bind / / \
    --proc /proc \
    --ro-bind "$HOME" "$HOME" \
    --bind "$HOME/Downloads" "$HOME/Downloads" \
    --tmpfs "$HOME/.config" \
    --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
    --setenv LD_PRELOAD /opt/QQ/__patch__/libhook.so \
    --chdir "$HOME" \
    /opt/QQ/qq
else
    /opt/QQ/__patch__/daemon "$0"
fi
