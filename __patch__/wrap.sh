#!/usr/bin/sh
/opt/QQ/__patch__/daemon &
PID=$!
bwrap --unshare-all --share-net \
  --dev-bind / / \
  --proc /proc \
  --ro-bind "$HOME" "$HOME" \
  --bind "$HOME/Downloads" "$HOME/Downloads" \
  --tmpfs "$HOME/.config" \
  --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
  --setenv LD_PRELOAD /opt/QQ/__patch__/libhook.so \
  --chdir "$HOME" \
  /opt/QQ/qq
kill -9 $PID
echo "exited."
