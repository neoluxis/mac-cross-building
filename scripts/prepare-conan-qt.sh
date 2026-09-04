#!/usr/bin/env bash
set -euo pipefail

# Conan Center's Qt recipes force "dynamic" OpenGL for every Windows build.
# Its ANGLE include path is incomplete when cross-building from macOS with a
# recent MinGW. Keep the consumer-selected mode instead; the public SDK uses
# desktop OpenGL, which links against Windows' native OpenGL implementation.
for qt_version in "${@:-5.15.19}"; do
    conan download "qt/$qt_version" --only-recipe --remote=conancenter >/dev/null
    recipe_file="$(conan cache path "qt/$qt_version")/conanfile.py"

    if grep -q '^[[:space:]]*self\.options\.opengl = "dynamic"' "$recipe_file"; then
        perl -pi -e 's/^([[:space:]]*)self\.options\.opengl = "dynamic"/$1# Keep the consumer-selected OpenGL mode for macOS cross-builds./' "$recipe_file"
    fi

    if [[ "$qt_version" == 6.* ]] && ! grep -q 'MAC2WIN_QT_HOST_PATH' "$recipe_file"; then
        perl -0pi -e 's/if cross_building\(self\):\n            self\.tool_requires\(f"qt\/\{self\.version\}"\)/if cross_building(self) and not os.getenv("MAC2WIN_QT_HOST_PATH"):\n            self.tool_requires(f"qt\/\{self.version\}")/' "$recipe_file"
        perl -0pi -e 's/tc\.cache_variables\["QT_HOST_PATH"\] = self\.dependencies\.direct_build\["qt"\]\.package_folder\n            # Stand-in for Qt6CoreTools - which is loaded for the executable targets\n            tc\.cache_variables\["CMAKE_PROJECT_Qt_INCLUDE"\] = os\.path\.join\(self\.dependencies\.direct_build\["qt"\]\.package_folder, self\._cmake_executables_file\)\n            # Ensure tools for host are always built\n            tc\.cache_variables\["QT_FORCE_BUILD_TOOLS"\] = True/qt_host_path = os.getenv("MAC2WIN_QT_HOST_PATH")\n            if qt_host_path:\n                tc.cache_variables["QT_HOST_PATH"] = qt_host_path\n                tc.cache_variables["QT_FORCE_BUILD_TOOLS"] = True\n            else:\n                tc.cache_variables["QT_HOST_PATH"] = self.dependencies.direct_build["qt"].package_folder\n                # Stand-in for Qt6CoreTools - which is loaded for the executable targets\n                tc.cache_variables["CMAKE_PROJECT_Qt_INCLUDE"] = os.path.join(self.dependencies.direct_build["qt"].package_folder, self._cmake_executables_file)\n                # Ensure tools for host are always built\n                tc.cache_variables["QT_FORCE_BUILD_TOOLS"] = True/' "$recipe_file"
    fi

    if [[ "$qt_version" == 6.* ]]; then
        # A macOS host does not imply a macOS target. Requiring macdeployqt.exe
        # for a Windows package is a Conan Center cross-build recipe bug.
        perl -0pi -e 's/if self\.settings_build\.os == "Macos" and self\.settings\.os != "iOS":/if self.settings.os == "Macos":/' "$recipe_file"
        # windeployqt is a host-side program too and cannot be built as a
        # runnable Windows tool during this cross build. The SDK supplies its
        # own recursive MinGW-aware replacement.
        perl -0pi -e 's/if self\.settings\.os == "Windows":\n            targets\.extend\(\["windeployqt"\]\)/if self.settings.os == "Windows" and not cross_building(self):\n            targets.extend(["windeployqt"])/' "$recipe_file"
    fi
done
