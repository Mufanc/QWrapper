#!/usr/bin/sh
exec bwrap --unshare-all --share-net \
  --dev-bind / / \
  --proc /proc \
  --tmpfs "$HOME" \
  --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
  --chdir "$HOME" \
  /opt/QQ/qq
