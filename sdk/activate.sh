#!/usr/bin/env bash
# Source this file (do not execute it) to use the shared macOS -> Windows SDK.
# Usage: source /path/to/activate.sh [5|6]

if [ -n "${ZSH_VERSION:-}" ]; then
    # `%x` is the path of the sourced file in zsh.  Keep it in eval so bash
    # never has to parse zsh-specific parameter-expansion flags.
    eval '_mac2win_activate_source=${(%):-%x}'
else
    _mac2win_activate_source="${BASH_SOURCE[0]}"
fi

_mac2win_activate_dir="$(cd "$(dirname "$_mac2win_activate_source")" && pwd -P)"
export MAC2WIN_SDK_ROOT="$_mac2win_activate_dir"
export MAC2WIN_TOOLCHAIN_FILE="$MAC2WIN_SDK_ROOT/cmake/toolchains/mingw-w64-x86_64.cmake"
export MAC2WIN_DEPLOYER="$MAC2WIN_SDK_ROOT/bin/mingwdeployqt"
export MAC2WIN_PACKAGER="$MAC2WIN_SDK_ROOT/bin/makensis-package"

mac2win_use_qt() {
    case "$1" in
        5|6) ;;
        *) echo "Mac2Win: Qt major must be 5 or 6 (got '$1')." >&2; return 2 ;;
    esac

    _mac2win_qt_root="$MAC2WIN_SDK_ROOT/qt$1/package"
    if [ ! -d "$_mac2win_qt_root" ]; then
        echo "Mac2Win: Qt $1 SDK is not installed at $_mac2win_qt_root." >&2
        return 1
    fi

    export MAC2WIN_QT_MAJOR="$1"
    export MAC2WIN_QT_ROOT="$_mac2win_qt_root"
    export QT_ROOT_DIR="$MAC2WIN_QT_ROOT"
    export PATH="$MAC2WIN_SDK_ROOT/bin:$MAC2WIN_QT_ROOT/bin:$PATH"
}

# Preserve an explicitly selected CMake toolchain; otherwise let ordinary
# `cmake -S ... -B ...` invocations use this SDK without a long path.
export CMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE:-$MAC2WIN_TOOLCHAIN_FILE}"
mac2win_use_qt "${1:-${MAC2WIN_QT_MAJOR:-6}}" || return $?

unset _mac2win_activate_dir _mac2win_activate_source _mac2win_qt_root
