#!/bin/sh

set -ex

pacman -Syu --noconfirm --needed base-devel rustup pacman-contrib

rustup toolchain install stable
rustup toolchain install nightly

chmod -R a+rw .
useradd builder -m && echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

sudo -u builder BUILDARGS="--syncdeps --noconfirm" make
