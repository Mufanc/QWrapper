set -e

JSON_URL='https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/pcConfig.json'
CFG="$(curl -fsSL "$JSON_URL")"

export SOURCE="$(jq -r '.Linux.x64DownloadUrl.deb' <<<"$CFG")"
export PKGVER="$(jq -r '.Linux.version' <<<"$CFG")"
export PKGROOT="$(realpath "$(dirname "$0")")"

envsubst "$(env | grep -Po '^[A-Z_]+(?==)' | sed 's/^/$/g')" < PKGBUILD.proto > PKGBUILD
updpkgsums

# shellcheck disable=SC2086
makepkg -f $BUILDARGS
