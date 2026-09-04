#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk_root="${MAC2WIN_SDK_ROOT:-$HOME/.local/lib/x86-64-mingw-w64-gcc}"
export CONAN_HOME="$sdk_root/conan"
export PATH="/opt/homebrew/bin:$PATH"

qt5_version="5.15.19"
# Conan Center currently trails Homebrew by one patch release. Qt host tools
# are compatible within the same minor line, so pair target 6.11.1 with the
# Homebrew 6.11.x host package instead of compiling another native Qt.
qt6_version="6.11.1"
mkdir -p "$CONAN_HOME/profiles" "$sdk_root/qt5" "$sdk_root/qt6"

# Native Qt host tools such as qsb use QTemporaryDir. Keep their temporary
# files in the SDK tree so restricted macOS environments can create them.
mac2win_tmp="$sdk_root/tmp"
mkdir -p "$mac2win_tmp"
export TMPDIR="$mac2win_tmp"

if [[ ! -f "$CONAN_HOME/profiles/default" ]]; then
    conan profile detect --force
fi
if ! conan remote list | grep -q '^conancenter:'; then
    conan remote add conancenter https://center2.conan.io
fi

"$project_dir/scripts/prepare-conan-qt.sh" "$qt5_version" "$qt6_version"

common_options=(
    -o 'qt/*:shared=True'
    -o 'qt/*:opengl=desktop'
    -o 'qt/*:openssl=False'
    -o 'qt/*:with_mysql=False'
    -o 'qt/*:with_pq=False'
    -o 'qt/*:with_odbc=False'
    -o 'qt/*:with_sqlite3=False'
    -o 'qt/*:with_zstd=False'
    -o 'qt/*:with_brotli=False'
    -o 'qt/*:with_harfbuzz=False'
    -o 'qt/*:with_md4c=False'
    -o 'qt/*:with_gstreamer=False'
    -o 'qt/*:with_openal=False'
    -o 'qt/*:cross_compile=x86_64-w64-mingw32-'
)

# Homebrew's native OpenSSL CMake package must never leak into a Windows
# try_compile. Qt still probes OpenSSL while configuring even when the feature
# is disabled; hiding the host package keeps that probe inside the target SDK.
target_conf=(
    -c:h 'tools.cmake.cmaketoolchain:extra_variables={"CMAKE_DISABLE_FIND_PACKAGE_OpenSSL":"TRUE","CMAKE_DISABLE_FIND_PACKAGE_DBus1":"TRUE","CMAKE_DISABLE_FIND_PACKAGE_harfbuzz":"TRUE","CMAKE_DISABLE_FIND_PACKAGE_md4c":"TRUE"}'
)

qt6_host_path="$(brew --prefix qt@6 2>/dev/null || brew --prefix qt)"
for host_tool in share/qt/libexec/moc share/qt/libexec/uic share/qt/libexec/rcc bin/qsb; do
    if [[ ! -x "$qt6_host_path/$host_tool" ]]; then
        echo "Homebrew Qt 6 host tool is missing: $qt6_host_path/$host_tool" >&2
        exit 1
    fi
done

install_qt() {
    local major="$1"
    local version="$2"
    shift 2
    local output="$sdk_root/qt$major/conan"
    local graph="$output/graph.json"
    mkdir -p "$output"

    if [[ "$major" == 6 ]]; then
        export MAC2WIN_QT_HOST_PATH="$qt6_host_path"
    else
        unset MAC2WIN_QT_HOST_PATH || true
    fi

    conan install --requires="qt/$version" \
        --profile:build=default \
        --profile:host="$project_dir/profiles/windows-mingw" \
        --build=missing \
        --generator=CMakeDeps \
        --output-folder="$output" \
        --format=json \
        --out-file="$graph" \
        "${common_options[@]}" "${target_conf[@]}" "$@"

    local package_id
    package_id="$(jq -r --arg prefix "qt/$version" \
        '.graph.nodes[] | select(.ref != null and (.ref | startswith($prefix))) | .package_id' \
        "$graph" | head -n 1)"
    if [[ -z "$package_id" || "$package_id" == null ]]; then
        echo "Cannot determine qt/$version package id" >&2
        exit 1
    fi

    local package_dir
    package_dir="$(conan cache path "qt/$version:$package_id")"
    mkdir -p "$sdk_root/qt$major/package"
    rsync -a --delete "$package_dir/" "$sdk_root/qt$major/package/"
    printf '%s\n' "$version" >"$sdk_root/qt$major/VERSION"
}

build_majors="${MAC2WIN_QT_MAJORS:-5 6}"
if [[ " $build_majors " == *" 5 "* ]]; then
    install_qt 5 "$qt5_version" \
        -o 'qt/*:config=-no-feature-wmf' \
        -o 'qt/*:qtmultimedia=True' \
        -o 'qt/*:qtserialport=True' \
        -o 'qt/*:qtgamepad=True' \
        -o 'qt/*:qttools=True'
fi

# Qt Gamepad is marked "ignore" by Qt in the Qt 6 source tree and is not a
# buildable Qt 6 module. The other requested Qt 6 modules are enabled here.
if [[ " $build_majors " == *" 6 "* ]]; then
    install_qt 6 "$qt6_version" \
        -s:h 'compiler.cppstd=gnu17' \
        -o 'qt/*:qtmultimedia=True' \
        -o 'qt/*:qtserialport=True' \
        -o 'qt/*:qttools=True'
fi

mkdir -p "$sdk_root/bin" "$sdk_root/cmake/toolchains" "$sdk_root/cmake" "$sdk_root/share/nsis" "$sdk_root/runtime" "$sdk_root/docs"
cp "$project_dir/sdk/bin/mingwdeployqt" "$sdk_root/bin/"
cp "$project_dir/sdk/bin/makensis-package" "$sdk_root/bin/"
cp "$project_dir/sdk/activate.sh" "$sdk_root/activate.sh"
cp "$project_dir/sdk/cmake/Mac2WinDeploy.cmake" "$sdk_root/cmake/"
cp "$project_dir/sdk/cmake/toolchains/mingw-w64-x86_64.cmake" "$sdk_root/cmake/toolchains/"
cp "$project_dir/sdk/share/nsis/package.nsi" "$sdk_root/share/nsis/"
cp "$project_dir/README.md" "$sdk_root/README.md"
cp "$project_dir/docs/macOS到Windows-Qt开发环境完整手册.md" "$sdk_root/docs/"
chmod +x "$sdk_root/bin/mingwdeployqt" "$sdk_root/bin/makensis-package" "$sdk_root/activate.sh"

mingw_target_root="$(brew --prefix mingw-w64)/toolchain-x86_64/x86_64-w64-mingw32"
cp "$mingw_target_root/lib/libgcc_s_seh-1.dll" "$sdk_root/runtime/"
cp "$mingw_target_root/lib/libstdc++-6.dll" "$sdk_root/runtime/"
cp "$mingw_target_root/bin/libwinpthread-1.dll" "$sdk_root/runtime/"

echo "Public Qt/MinGW SDK installed at: $sdk_root"
