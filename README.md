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

## 📦 一键式 RootFS 自动制作与打包指南

为了让您能够直接部署可开机启动的嵌入式系统，我们设计了全新的一键化 RootFS 制作工具。该工具会自动结合编译好的 BusyBox 产物、交叉编译器的动态链接库、以及预设的系统配置模板，一键打包生成完美符合 Linux 标准（如 `root:root` 属主和特殊设备节点）的根文件系统。

### 1. 运行一键制作脚本
在您的宿主机终端直接运行以下脚本：
```bash
./make_rootfs.sh
```
该脚本采用自适应架构：
- **宿主机（macOS/Linux）环境**：自动检查 Docker 并拉起 `busybox-imx6ul-builder` 容器，编译最新的 BusyBox 产物，并在容器本地的 OverlayFS 文件系统中以 `root` 权限制作根文件系统，彻底绕过了宿主机无法创建 Linux 设备物理节点的平台差异。
- **构建输出**：
  1. **`rootfs/`**：同步回宿主机的可浏览目录树，去除了会导致宿主机系统错误的 `/dev` 设备物理节点，方便您在宿主机 IDE 中直观浏览和搜索。
  2. **`rootfs.tar.bz2`**：完美的嵌入式生产级部署包，完整包含 `/dev/console` 与 `/dev/null` 设备物理节点，且所有文件的所有者已在打包时强制重置为 `root:root`。

### 2. 📂 模块化系统配置模板 (`rootfs_template/`)
项目根目录下的 **`rootfs_template/`** 是专为开发者打造的独立配置模板文件夹。您可以直接在此目录编辑配置文件，它们会在下次运行 `./make_rootfs.sh` 时被自动部署并应用：
- **`etc/inittab`**：定义系统 init 进程行为（预配置开机调起交互式控制台 Shell）。
- **`etc/init.d/rcS`**：开机自启动初始化脚本（自动挂载虚拟文件系统、运行 `mdev` 动态热插拔设备管理器等）。
- **`etc/fstab`**：挂载表（预置挂载 `proc`、`sysfs`、`tmpfs`、`devtmpfs`）。
- **`etc/profile`**：用户环境与定制设计的**高对比度 HSL 配色 Shell 管理员命令行提示符**（`[root@imx6ul:/]#`）。
- **`etc/passwd` / `shadow` / `group`**：系统用户与免密极速调试策略（默认 root 密码为空，回车即登录）。
- **`etc/hostname` / `hosts`**：网络主机名配置。
- **`etc/issue`**：控制台欢迎横幅。

### 3. 🛡️ 严格的文件权限安全净化
为了保障嵌入式系统的安全性并防止由于宿主机操作系统权限差异导致的“天坑”，脚本在打包前会在容器内以 `root` 身份执行**强制性的安全洗涤与重置**：
- **常规文件** 统一重置为 `644` 权限；**目录** 统一重置为 `755` 权限。
- **可执行文件**（`/bin`、`/sbin`、`/usr` 以及自启动目录 `/etc/init.d/rcS`）自动获取 `755` 权限。
- **共享链接库**（`/lib`）统一获取 `755` 权限，软链接完整保持。
- **机密账密文件**（`/etc/shadow`）强制限制为仅 root 可读写的 `600` 权限。
- **临时空间**（`/tmp`）强制打包为带有粘滞位的 `1777` 权限（`drwxrwxrwt`）。
- **管理员主目录**（`/root`）强制限制为 `700` 权限。

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
