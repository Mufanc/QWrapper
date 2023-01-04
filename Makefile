.PHONY : clean extract patch install

LinuxQQ-patched.deb: LinuxQQ.deb clean extract patch
	rm -f LinuxQQ-patched.deb
	dpkg-deb --root-owner-group -b extract LinuxQQ-patched.deb
	$(MAKE) clean
	echo "Build Finished." > /dev/pts/0  # KDE 系统消息服务

clean:
	rm -rf extract

extract:
	dpkg -X LinuxQQ.deb extract
	dpkg -e LinuxQQ.deb extract/DEBIAN

patch:
	cp -r __patch__ extract/opt/QQ
	( \
	    echo ''; \
	    echo 'rm -f /usr/bin/qq'; \
	    echo 'cp /opt/QQ/__patch__/wrap.sh /usr/bin/qq'; \
	    echo 'chmod +x /usr/bin/qq'; \
	) >> extract/DEBIAN/postinst
	sed -i -E 's@(Depends: .*)@\1, bubblewrap, python3@' extract/DEBIAN/control
	sed -i -E 's@(Name=.*)@Name=QQ Wrapper@' extract/usr/share/applications/qq.desktop
	sed -i -E 's@(Exec=.*)@Exec=/usr/bin/qq@' extract/usr/share/applications/qq.desktop

LinuxQQ.deb:
	curl -o LinuxQQ.deb $$( \
	    curl https://im.qq.com/rainbow/linuxQQDownload/ | \
	        grep -Eo '"deb":"[^"]+"' | \
	        grep -Eo 'https://.*_amd64\.deb' \
	)

install:
	sudo apt install ./LinuxQQ-patched.deb
