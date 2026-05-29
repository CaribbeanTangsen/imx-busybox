# 适用于 i.MX6UL (ARM Cortex-A7) 的 BusyBox 构建环境

本仓库包含专为 **i.MX6UL (ARM 32位硬浮点)** 架构优化并配置的 **BusyBox** 源码及一键化构建工具。

项目内置了基于 **Docker** 的容器化交叉编译环境，并配置了您指定的私有镜像仓库前缀以及 **清华大学开源软件镜像源**，可实现极为迅速的编译工具链部署与代码编译。

---

## 🛠️ 交叉编译环境说明

我们提供了一套容器化的交叉编译解决方案，您无需在宿主机上安装繁琐的交叉编译器，即可安全、隔离地完成 BusyBox 的配置与编译。

### 核心特性
- **Docker 基础镜像**：使用您指定的私有前缀 `hub.lantusoft.com.cn/docker-hub/library/ubuntu:22.04`。
- **极速 APT 包管理器源**：容器内部已自动配置为 **清华源** (`mirrors.tuna.tsinghua.edu.cn`)，支持 `x86_64` 与 `ARM64` (例如 Apple Silicon M系列芯片 Mac) 宿主机架构。
- **目标交叉编译器**：预装 `gcc-arm-linux-gnueabihf` 编译器及完整的 `armhf` 目标平台系统头文件，可编译出完美适配 ARM Cortex-A7 架构的二进制程序。

---

## 🚀 编译与配置指南

项目根目录下提供了一个功能强大的构建脚本 `build.sh`，可为您自动管理 Docker 容器的创建、挂载和编译流程。

### 1. 一键默认编译
如果您本地尚未生成 `.config` 配置文件，该命令将自动使用 BusyBox 的默认配置 (`make defconfig`)，并调用宿主机的所有 CPU 核心进行并行编译，最后将生成的文件打包输出到 `_install` 目录：
```bash
./build.sh
```

### 2. 交互式功能裁剪配置 (`menuconfig`)
如果您需要定制 BusyBox 的功能（例如开启/关闭特定的 Linux 命令、配置静态编译、添加特定的系统小工具等），可以使用以下命令在终端中直接打开交互式配置菜单：
```bash
./build.sh --config
```
*提示：这将在 Docker 容器内调起 BusyBox 标准的 ncurses 蓝色配置界面，操作体验与本地运行完全一致。*

### 3. 重置配置为默认值
如果您想丢弃当前的修改，并将 `.config` 配置文件重置为 BusyBox 官方的默认配置：
```bash
./build.sh --defconfig
```

### 4. 深度清理项目
如果您需要清除所有的编译中间产物、临时文件和当前的 `.config` 配置（相当于 `make mrproper`）：
```bash
./build.sh --clean
```

### 5. 强制重新构建 Docker 编译镜像
当您修改了 `Dockerfile` 并需要强制重新构建编译镜像时：
```bash
./build.sh --rebuild
```

---

## 📂 编译产物与部署

所有的构建结果都将自动同步并输出到项目根目录下的 **`_install/`** 目录中。

### 1. 目标文件系统目录结构
`_install/` 目录中已经根据 BusyBox 的配置生成了标准的 Linux 嵌入式根文件系统目录树，并在内部创建了指向 `busybox` 核心程序的软链接：
- `_install/bin/` （包含常用的基础命令，如 `busybox`、`sh`、`ls`、`cat`、`cp` 等）
- `_install/sbin/` （包含系统管理命令，如 `init`、`reboot` 等）
- `_install/usr/bin/`
- `_install/usr/sbin/`

### 2. 验证二进制文件架构
您可以在宿主机终端中使用 `file` 命令来校验编译出来的二进制程序属性：
```bash
file _install/bin/busybox
```
**正确输出示例：**
```
_install/bin/busybox: ELF 32-bit LSB pie executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, ...
```

### 3. 部署到您的开发板
您可以直接将 `_install/` 目录下的所有子目录拷贝到您的 i.MX6UL 目标板根文件系统（`rootfs`）中：
```bash
# 例如：拷贝到您本地的 NFS 挂载目录中
cp -a _install/* /path/to/your/nfs/rootfs/
```
