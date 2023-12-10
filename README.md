# QWrapper

[![repack](https://img.shields.io/github/actions/workflow/status/Mufanc/QWrapper/ci.yml?branch=archlinux&label=repack)](https://github.com/Mufanc/QWrapper/actions)

一款 Linux QQ 自动重打包工具，使用 [bwrap](https://github.com/containers/bubblewrap) 为其获取一定程度上的隔离

## 功能

* 基本的存储隔离

* 直接打开「请复制后使用浏览器访问」的页面

## 使用

* 打包 & 安装

```bash
git clone https://github.com/Mufanc/QWrapper
cd QWrapper
make
pacman -U qwrapper*.pkg.*
```

## 定制

bwrap 命令放在 [launcher.sh](./launcher.sh) 中，将被安装到 `/opt/QQ/launcher.sh` 你可以修改此文件来定制自己的 bwrap 沙盒环境
