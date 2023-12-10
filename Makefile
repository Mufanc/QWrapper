.PHONY : all clean
.OHESHELL :

all:
	./build.sh

clean: 
	rm -rf PKGBUILD src pkg *.deb *.tar.zst
