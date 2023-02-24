.PHONY : clean extract patch install hotfix

LinuxQQ-patched.deb: LinuxQQ.deb clean patch
	rm -f LinuxQQ-patched.deb
	dpkg-deb --root-owner-group -b extract LinuxQQ-patched.deb
	$(MAKE) clean

extract:
	dpkg -X LinuxQQ.deb extract
	dpkg -e LinuxQQ.deb extract/DEBIAN

patch: extract __patch__/libhook.so __patch__/daemon
	cp -r __patch__ extract/opt/QQ
	( \
	    echo ''; \
	    echo 'rm -f /usr/bin/qq'; \
	    echo 'cp /opt/QQ/__patch__/wrap.sh /usr/bin/qq'; \
	    echo 'chmod +x /usr/bin/qq'; \
		echo 'mkdir -p $$HOME/.config/QQ' \
	) >> extract/DEBIAN/postinst
	sed -i -E 's@(Depends: .*)@\1, bubblewrap@' extract/DEBIAN/control
	sed -i -E 's@(Name=.*)@Name=QQ Wrapper@' extract/usr/share/applications/qq.desktop
	sed -i -E 's@(Exec=.*)@Exec=/usr/bin/qq@' extract/usr/share/applications/qq.desktop

__patch__/libhook.so: hook.cpp
	clang++ hook.cpp -fPIC -shared -o __patch__/libhook.so -std=gnu++17

__patch__/daemon: daemon.cpp
	clang++ daemon.cpp -o __patch__/daemon

LinuxQQ.deb:
	curl -o LinuxQQ.deb $$( \
	    curl https://im.qq.com/rainbow/linuxQQDownload/ | \
	        grep -Eo '"deb":"[^"]+"' | \
	        grep -Eo 'https://.*_amd64\.deb' \
	)

install:
	sudo apt purge linuxqq
	sudo apt install ./LinuxQQ-patched.deb

hotfix: __patch__/libhook.so __patch__/daemon
	sudo cp __patch__/wrap.sh /usr/bin/qq
	sudo cp __patch__/libhook.so /opt/QQ/__patch__
	sudo cp __patch__/daemon /opt/QQ/__patch__

clean:
	rm -rf extract
