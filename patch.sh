# 下载 deb 包
if [ ! -f LinuxQQ.deb ]; then
    # shellcheck disable=SC2046
    curl -o LinuxQQ.deb $( \
        curl https://im.qq.com/rainbow/linuxQQDownload/ | \
            grep -Eo '"deb":"[^"]+"' | \
            grep -Eo 'https://.*_amd64\.deb' \
    )
fi

# 删除旧文件
rm -f LinuxQQ-patched.deb
rm -rf extract

# 解包
dpkg -X LinuxQQ.deb extract
dpkg -e LinuxQQ.deb extract/DEBIAN

# 补丁
cp wrap.sh extract/opt/QQ
(
    echo '';
    echo 'rm -f /usr/bin/qq';
    echo 'cp /opt/QQ/wrap.sh /usr/bin/qq';
    echo 'chmod +x /usr/bin/qq';
) >> extract/DEBIAN/postinst
sed -i -E 's@(Depends: .*)@\1, bubblewrap@' extract/DEBIAN/control
sed -i -E 's@(Name=.*)@Name=QQ Wrapper@' extract/usr/share/applications/qq.desktop
sed -i -E 's@(Exec=.*)@Exec=/usr/bin/qq@' extract/usr/share/applications/qq.desktop

# 打包
dpkg -b extract LinuxQQ-patched.deb

# 清理
rm -rf extract
