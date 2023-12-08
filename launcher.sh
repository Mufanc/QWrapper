#!/usr/bin/env sh
mkdir -p $HOME/.config/QQ
killall -9 /opt/QQ/main
exec bwrap --unshare-all --share-net \
    --dev-bind / / \
    --proc /proc \
    --ro-bind "$HOME" "$HOME" \
    --bind "$HOME/Downloads" "$HOME/Downloads" \
    --tmpfs "$HOME/.config" \
    --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
    --tmpfs "$HOME/.config/QQ/crash_files" \
    --chdir "$HOME" \
    /opt/QQ/main
