set -e

export SOURCE=$(curl -s https://im.qq.com/rainbow/linuxQQDownload/ | grep -Eo '"deb":"[^"]+"' | grep -Eo 'https://.*_amd64.*\.deb')
export PKGVER=$(echo "$SOURCE" | awk -F '_' '{print $2}')
export PKGROOT=$(realpath "$(dirname "$0")")

envsubst "$(env | grep -Po '^[A-Z_]+(?==)' | sed 's/^/$/g')" < PKGBUILD.proto > PKGBUILD
updpkgsums

# shellcheck disable=SC2086
makepkg -f $BUILDARGS
