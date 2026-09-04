# macOS 到 Windows x86_64 Qt 开发环境完整手册

本手册从一台干净的 macOS（Apple Silicon 或 Intel）开始，搭建使用
MinGW-w64 GCC 的 Windows x86_64 Qt 开发环境。公共 SDK 默认安装到
`~/.local/lib/x86-64-mingw-w64-gcc`；应用项目的构建产物、部署目录和
安装包始终留在各自项目中，不会写入公共 SDK。

目标 Qt 版本与模块如下：

| 版本 | 已构建模块 |
| --- | --- |
| Qt 5.15.19 | Base、Tools、Multimedia、SerialPort、Gamepad、Desktop OpenGL |
| Qt 6.11.1 | Base、Tools、Multimedia、SerialPort、Desktop OpenGL |

Qt 6 上游已将 Gamepad 标记为不构建模块，因此 Qt 6 没有 Gamepad。所有
Windows 目标代码、库和 DLL 均由 `x86_64-w64-mingw32-gcc/g++` 构建；Qt 的
`moc`、`uic`、`rcc`、`qsb` 等工具则是可在 macOS 上执行的原生工具。

## 1. 前置条件与 Homebrew 依赖

需要 macOS 13 或更高版本、管理员权限和网络。先安装 Homebrew（如果尚未
安装），命令来自 Homebrew 官方安装器：

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

让当前终端找到 Homebrew。Apple Silicon 通常使用第一行，Intel 通常使用第二行：

```sh
eval "$(/opt/homebrew/bin/brew shellenv)"
# Intel Mac：eval "$(/usr/local/bin/brew shellenv)"
```

安装本流程所需的全部 Homebrew 软件：

```sh
brew update
brew install cmake ninja conan mingw-w64 qt nsis jq perl
```

核验关键命令。`x86_64-w64-mingw32-g++` 必须存在，且其版本会显示为 GCC：

```sh
cmake --version
conan --version
ninja --version
makensis -VERSION
x86_64-w64-mingw32-g++ --version
brew --prefix mingw-w64
brew --prefix qt
```

不要在 macOS 上用 Apple Clang 编译 Windows 程序。本流程始终由 Homebrew 的
MinGW-w64 GCC 交叉编译器生成 PE32+ Windows x86_64 文件。

## 2. 获取本项目并构建公共 SDK

假设项目目录为 `~/Desktop/Mac2Win`。若从版本库获取，先进入该目录；若目录
已经存在，直接从第二条命令开始。

```sh
cd ~/Desktop/Mac2Win
chmod +x scripts/*.sh sdk/bin/* sdk/activate.sh
./scripts/build-public-qt-sdk.sh
```

该命令是完整的 SDK 构建入口。首次执行会下载 Conan 配方和源码，并可能编译
Qt，耗时较长；之后 Conan 缓存和公共 SDK 会被复用。它实际完成以下操作：

```sh
# 脚本内部使用的公共位置
export MAC2WIN_SDK_ROOT="$HOME/.local/lib/x86-64-mingw-w64-gcc"
export CONAN_HOME="$MAC2WIN_SDK_ROOT/conan"

# 自动执行或等价执行的 Conan 初始化命令
conan profile detect --force
conan remote add conancenter https://center2.conan.io

# 为 macOS -> MinGW 交叉构建准备 Conan Qt 配方，然后分别解析/构建 Qt 5 和 Qt 6
./scripts/prepare-conan-qt.sh 5.15.19 6.11.1
conan install --requires=qt/5.15.19 --profile:build=default \
  --profile:host=profiles/windows-mingw --build=missing --generator=CMakeDeps
conan install --requires=qt/6.11.1 --profile:build=default \
  --profile:host=profiles/windows-mingw --build=missing --generator=CMakeDeps
```

最后两条只是流程说明；请使用 `build-public-qt-sdk.sh`，因为它还传入了 Qt
模块开关、macOS 原生 Qt 6 host tools 路径、OpenGL 选项、生成目录以及运行时 DLL
复制等必要参数。不要手工删减这些参数。

只重建一个 Qt 主版本时可使用：

```sh
cd ~/Desktop/Mac2Win
MAC2WIN_QT_MAJORS=5 ./scripts/build-public-qt-sdk.sh
# 或：MAC2WIN_QT_MAJORS=6 ./scripts/build-public-qt-sdk.sh
```

构建完成后的关键目录：

```text
~/.local/lib/x86-64-mingw-w64-gcc/
├── activate.sh                         # shell 环境初始化
├── qt5/package/                        # Qt5 Windows headers/libs/DLLs/qmake
├── qt6/package/                        # Qt6 Windows headers/libs/DLLs
├── cmake/toolchains/mingw-w64-x86_64.cmake
├── cmake/Mac2WinDeploy.cmake
├── bin/mingwdeployqt                   # 递归 DLL/Qt 插件部署
├── bin/makensis-package                # 安装包和更新包生成
├── runtime/                            # MinGW 运行时 DLL
└── share/nsis/package.nsi              # NSIS 模板
```

## 3. 每个终端的环境初始化

新开终端后执行一次 `source`，默认选择 Qt 6：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 6
```

使用 Qt 5 或在同一终端切换版本：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 5
mac2win_use_qt 6
```

脚本会设置：

```text
MAC2WIN_SDK_ROOT
MAC2WIN_TOOLCHAIN_FILE
CMAKE_TOOLCHAIN_FILE
MAC2WIN_QT_MAJOR
MAC2WIN_QT_ROOT
MAC2WIN_DEPLOYER
MAC2WIN_PACKAGER
PATH
```

确认当前版本和交叉编译器：

```sh
echo "$MAC2WIN_QT_MAJOR"
echo "$CMAKE_TOOLCHAIN_FILE"
x86_64-w64-mingw32-g++ --version
```

## 4. CMake 项目构建

以下是一个 Qt 6 Widgets 项目的最小 `CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyApp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Multimedia SerialPort)
add_executable(MyApp WIN32 src/main.cpp)
target_link_libraries(MyApp PRIVATE Qt6::Widgets Qt6::Multimedia Qt6::SerialPort)
```

构建命令不需要再填写 toolchain 的完整路径：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 6
cmake -S . -B build-win -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-win -j "$(sysctl -n hw.logicalcpu)"
file build-win/MyApp.exe
```

Qt 5 项目将 `Qt6` 改为 `Qt5`，并在配置前选择 Qt 5：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 5
cmake -S . -B build-win-qt5 -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-win-qt5
```

一个构建目录只能固定一种 Qt 主版本和一种 toolchain 配置。切换 Qt 5/6 时使用
新的构建目录，或删除该项目的旧 `build-win` 后重新配置。

## 5. Qt Creator 配置

Qt Creator 可以使用本工具链构建 Windows 程序，但生成的 Windows EXE 不能在
macOS 上直接运行。Qt 6 请使用 CMake Kit；Qt 5 可以使用 CMake Kit 或 qmake Kit。

在 **Preferences → Kits** 新建 Kit，填写：

```text
C compiler:   /opt/homebrew/bin/x86_64-w64-mingw32-gcc
C++ compiler: /opt/homebrew/bin/x86_64-w64-mingw32-g++
CMake:        /opt/homebrew/bin/cmake
Generator:    Ninja
```

Apple Intel Homebrew 的对应前缀是 `/usr/local/bin`。在 Kit 的 CMake Configuration
加入如下三项（Qt 5 把第二项改为 `5`）：

```text
CMAKE_TOOLCHAIN_FILE:FILEPATH=/Users/你的用户名/.local/lib/x86-64-mingw-w64-gcc/cmake/toolchains/mingw-w64-x86_64.cmake
MAC2WIN_QT_MAJOR:STRING=6
CMAKE_BUILD_TYPE:STRING=Release
```

若 Creator 从 Finder 启动且找不到 `brew`，在该 Kit 的 Environment 中将
`PATH` 设置为 `/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`。Qt5 qmake Kit
可把 Qt Version 指向
`~/.local/lib/x86-64-mingw-w64-gcc/qt5/package/bin/qmake`，其 spec 是
`win32-g++`。不要把 Qt6 公共目录的 `qmake.exe` 加入 Creator；它是 Windows
目标程序，不能在 macOS 上执行。

## 6. qmake 项目构建（Qt 5）

对 `.pro` 项目（例如传统 Qt5 工程），在项目外创建构建目录，避免修改原项目：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 5
mkdir -p /tmp/myapp-mingw-build
cd /tmp/myapp-mingw-build
qmake -spec win32-g++ /绝对路径/到/MyApp.pro
make -j"$(sysctl -n hw.logicalcpu)"
```

生成的 Makefile 使用 `x86_64-w64-mingw32-g++`，输出为 Windows `.exe`。qmake
是 macOS 可运行的生成工具；不要在 macOS 上直接执行生成的 `.exe`。Qt 6 新项目
优先使用 CMake。

## 7. 部署 Windows 可运行目录

部署器复制应用 EXE、递归发现其导入 DLL、复制 Qt DLL、MinGW 运行时和 Qt 插件。
`--search` 可重复使用，用于 FFmpeg 等项目私有 DLL 目录：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 5
mingwdeployqt \
  --qt 5 \
  --source build-win-qt5/MyApp.exe \
  --dest dist/windows \
  --search third_party/ffmpeg/bin
```

也可以传入一个已包含多个 EXE/DLL 的目录：

```sh
mingwdeployqt --qt 6 --source staging --dest dist/windows
```

若出现 `warning: unresolved DLL`，不要忽略它。找到提供该 DLL 的目录后追加
`--search /该目录` 并重新部署。部署成功后把整个 `dist/windows` 目录复制或压缩到
64 位 Windows 机器运行；不要只复制 EXE。

## 8. 在 CMake 中加入部署和打包目标

把下列内容加到应用项目的 `CMakeLists.txt`，其中 `MyApp.ico` 必须是 Windows
ICO 文件：

```cmake
include("$ENV{MAC2WIN_SDK_ROOT}/cmake/Mac2WinDeploy.cmake")

mac2win_add_deploy_targets(MyApp
    QT_MAJOR 6
    DESTINATION "${CMAKE_BINARY_DIR}/deploy"
    PACKAGE_OUTPUT "${CMAKE_BINARY_DIR}/packages"
    PACKAGE_NAME "MyApp"
    VERSION "1.2.3"
    PUBLISHER "Example Company"
    PACKAGE_ICON "${CMAKE_SOURCE_DIR}/resources/MyApp.ico"
    EXTRA_DLL_DIRS "${CMAKE_SOURCE_DIR}/third_party/ffmpeg/bin")
```

`PACKAGE_NAME` 应保持稳定且包含 ASCII 字母或数字；它会转换为 Windows 注册表
应用 ID。版本升级时必须使用同一个 `PACKAGE_NAME`，更新包才能定位旧安装目录。

配置、构建和生成两个分发包：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 6
cmake -S . -B build-win -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-win --target MyApp_package
```

输出目录将包含：

```text
build-win/packages/
├── MyApp-1.2.3-setup.exe
└── MyApp-1.2.3-update.exe
```

## 9. 直接生成安装包与更新包

不使用 CMake 自定义目标时，先部署后调用命令行工具：

```sh
source ~/.local/lib/x86-64-mingw-w64-gcc/activate.sh 6

mingwdeployqt --qt 6 --source build-win/MyApp.exe --dest dist/windows

makensis-package \
  --source dist/windows \
  --output dist/packages \
  --name MyApp \
  --version 1.2.3 \
  --exe MyApp.exe \
  --publisher "Example Company" \
  --icon resources/MyApp.ico
```

`--icon` 是可选项，但推荐提供一个包含 16、32、48、256 像素图层的 `.ico` 文件。
它同时设置 setup 和 update EXE 的文件图标。

在 Windows 上的分发规则：

1. 首次安装运行 `MyApp-1.2.3-setup.exe`。它请求管理员权限、允许用户选择安装
   路径、写入 64 位注册表、创建当前用户桌面快捷方式和卸载器。
2. 下次发布时把 `--version` 改为新版本，但保持 `--name` 不变，重新生成包。
3. 已安装用户运行新的 `MyApp-新版本-update.exe`。该程序无界面，自动读取原
   安装路径并覆盖文件；未发现安装记录时会中止，不能替代首次安装。

## 10. 验证与常见问题

验证 Windows 目标文件格式：

```sh
file build-win/MyApp.exe
# 期望包含：PE32+ executable ... x86-64 ... for MS Windows
```

检查安装包不是仅几 KB。NSIS 日志中 `Install code` 是脚本逻辑体积，**不是**最终
安装包大小；请查看 `Total size` 或执行：

```sh
stat -f '%z bytes  %N' dist/packages/*.exe
```

常见问题处理：

| 现象 | 处理 |
| --- | --- |
| `Please, set the CMAKE_BUILD_TYPE` | CMake 配置命令加 `-DCMAKE_BUILD_TYPE=Release`。 |
| 找不到 `x86_64-w64-mingw32-g++` | 执行 `brew install mingw-w64`，并重新执行 Homebrew `shellenv`。 |
| 找不到 `makensis` | 执行 `brew install nsis`。 |
| Qt6 找不到 host tool | 执行 `brew install qt`，确认 `brew --prefix qt` 成功。 |
| 部署提示未解析 DLL | 向 `mingwdeployqt` 或 `EXTRA_DLL_DIRS` 添加提供该 DLL 的目录。 |
| Qt5 `QT += opengl` 失败 | 确认公共 SDK 通过本项目的 `build-public-qt-sdk.sh` 构建；其 Qt5 使用 Desktop OpenGL。 |
| 更新包提示未安装 | 先运行同一 `PACKAGE_NAME` 的 setup 包；更新包只用于已有安装。 |

## 11. SDK 维护边界

公共 SDK 只保存 Qt、MinGW 运行库、工具链和通用部署/打包工具。不要把应用 EXE、
应用私有 DLL、部署目录或安装包复制到
`~/.local/lib/x86-64-mingw-w64-gcc`。每个应用在自己的 `build-*`、`dist` 或
`packages` 目录保存这些产物。

升级 Homebrew 或重建公共 Qt 后，重新运行：

```sh
cd ~/Desktop/Mac2Win
./scripts/build-public-qt-sdk.sh
```

该命令会同步公共工具链、激活脚本、部署器、NSIS 模板与本手册，并保留应用项目
目录不受影响。
