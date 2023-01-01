# QWrapper

一款 Linux QQ 自动重打包工具，使用 [bubblewrap](https://github.com/containers/bubblewrap) 为其获取一定程度上的隔离

## 功能

* 基本的存储隔离

* 直接打开「请复制后使用浏览器访问」的页面

## 使用

* 卸载原 Linux QQ

```shell
sudo apt remove linuxqq
```

* 运行重打包脚本

```shell
git clone https://github.com/Mufanc/QWrapper
cd QWrapper
sh patch.sh
```

* 安装生成的 deb 包

```shell
sudo apt install ./LinuxQQ-patched.deb
```

## 定制

bwrap 启动命令放在项目 `__patch__` 目录下 [wrap.sh](./wrap.sh) 中，你可以修改此文件来定制自己的 bwrap 沙盒环境
