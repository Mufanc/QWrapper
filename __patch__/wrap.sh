#!/usr/bin/sh
exec bwrap --unshare-all --share-net \
  --dev-bind / / \
  --proc /proc \
  --ro-bind "$HOME" "$HOME" \
  --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
  --setenv LD_PRELOAD /opt/QQ/__patch__/libhook.so \
  --chdir "$HOME" \
  /opt/QQ/qq
