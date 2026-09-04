# Mac2Win Qt 工具链

Mac2Win 是 macOS 到 Windows x86_64 的 Qt 交叉编译工具链项目，不包含任何
应用示例工程。它构建并安装可由多个项目共同使用的 Qt 5/Qt 6、MinGW-w64 GCC
toolchain、CMake toolchain、部署器和 NSIS 打包器。

公共 SDK 默认位置：

```text
~/.local/lib/x86-64-mingw-w64-gcc
```

完整的从零安装、SDK 构建、CMake/qmake 使用、Qt Creator 配置、部署、安装包与
更新包流程，请阅读：[中文完整手册](docs/macOS到Windows-Qt开发环境完整手册.md)。

## 快速开始

```sh
brew install cmake ninja conan mingw-w64 qt nsis jq perl
cd ~/Desktop/Mac2Win
./scripts/build-public-qt-sdk.sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 6
```

之后在任意应用项目中直接配置：

```sh
cmake -S . -B build-win -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-win
```

`activate.sh` 会设置公共 CMake toolchain、Qt 主版本、部署和打包命令路径。
切换到 Qt 5：

```sh
mac2win_use_qt 5
```

## 仓库内容

```text
docs/       完整操作手册
profiles/   Conan Windows MinGW host profile
scripts/    公共 Qt SDK 构建与 Conan Qt 配方准备脚本
sdk/        将同步到公共 SDK 的激活、CMake、部署和 NSIS 文件
```

应用项目的源码、构建目录、EXE、私有 DLL、部署目录和安装包不属于本仓库，也不
应放入公共 SDK。
