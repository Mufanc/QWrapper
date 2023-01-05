#!/usr/bin/sh
export PATH="/opt/QQ/__patch__:$PATH"
exec bwrap --unshare-all --share-net \
  --dev-bind / / \
  --proc /proc \
  --ro-bind "$HOME" "$HOME" \
  --bind "$HOME/.config/QQ" "$HOME/.config/QQ" \
  --chdir "$HOME" \
  /opt/QQ/qq
