# QWrapper

[![repack](https://img.shields.io/github/actions/workflow/status/Mufanc/QWrapper/ci.yml?branch=master&label=repack)](https://github.com/Mufanc/QWrapper/actions)

一款 Linux QQ 自动重打包工具，使用 [bubblewrap](https://github.com/containers/bubblewrap) 为其获取一定程度上的隔离

## 功能

* 基本的存储隔离

* 直接打开「请复制后使用浏览器访问」的页面

## 使用

* 打包 & 安装

```bash
git clone https://github.com/Mufanc/QWrapper
cd QWrapper
make
make install  # 注意：此操作会卸载原 Linux QQ
```

[闪退问题](https://aur.archlinux.org/packages/linuxqq-nt-bwrap#comment-906014) 目前采用与 linuxqq-nt-bwrap 相同的 [Workaround 策略](https://aur.archlinux.org/cgit/aur.git/commit/?h=linuxqq-nt-bwrap&id=52d7eab4a3e70e1f2448919d4a6d2ad3f33a4d84)，但未添加依赖项，所以你可能需要手动安装 libvips 和 openslide

## 定制

bwrap 启动命令放在项目 `__patch__` 目录下 [wrap.sh](./wrap.sh) 中，你可以修改此文件来定制自己的 bwrap 沙盒环境
