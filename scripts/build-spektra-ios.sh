#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENG="$ROOT/vendor/spektralab/src/engine"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
IOS_MIN=17.0
MATH=(-fmetal-math-mode=safe -fmetal-math-fp32-functions=precise)
INCLUDES=(-I"$ENG/include" -I"$ENG/src" -I"$ENG/src/core" -I"$ENG/third_party/metal-cpp")
CXXFLAGS=(-std=c++20 -O2 -fPIC -fno-exceptions -fno-rtti -Wall -Wno-unused-parameter)

collect_cpp() {
  local f
  shopt -s nullglob
  cpp=()
  for f in "$ENG"/src/core/*.cpp "$ENG"/src/pipeline/*.cpp; do
    case "$(basename "$f")" in
      windows_unported.cpp) continue ;;
    esac
    cpp+=("$f")
  done
  cpp+=("$ENG/src/gpu/metal_gpu.cpp" "$ENG/src/gpu/metal_impl.cpp")
  shopt -u nullglob
}

build_one() {
  local sdk="$1" triple="$2" dest="$3"
  local sysroot out airs m air src obj
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  out="$ROOT/vendor/spektralab/ios/$dest"
  rm -rf "$out"
  mkdir -p "$out/air" "$out/obj"

  airs=()
  shopt -s nullglob
  for m in "$ENG"/src/shaders/*.metal; do
    air="$out/air/$(basename "$m" .metal).air"
    xcrun --sdk "$sdk" metal "${MATH[@]}" -mios-version-min="$IOS_MIN" -isysroot "$sysroot" -Werror -c "$m" -o "$air"
    airs+=("$air")
  done
  shopt -u nullglob
  xcrun --sdk "$sdk" metallib "${airs[@]}" -o "$out/spektrafilm.metallib"

  collect_cpp
  local objs=()
  for src in "${cpp[@]}"; do
    obj="$out/obj/$(basename "$src" .cpp).o"
    xcrun --sdk "$sdk" clang++ "${CXXFLAGS[@]}" "${INCLUDES[@]}" \
      -target "$triple" -mios-version-min="$IOS_MIN" -isysroot "$sysroot" \
      -c "$src" -o "$obj"
    objs+=("$obj")
  done
  xcrun --sdk "$sdk" ar rcs "$out/libspektrafilm_engine.a" "${objs[@]}"
  echo "built $dest -> $out"
}

bundle_resources() {
  local dest="$ROOT/HalfCam/Resources/engine"
  rm -rf "$dest"
  mkdir -p "$dest/profiles"
  rsync -a --exclude 'spektrafilm.metallib' "$ENG/resources/" "$dest/"
  if [ -d "$ENG/resources_product/profiles" ]; then
    rsync -a "$ENG/resources_product/profiles/" "$dest/profiles/"
  fi
  if [ -f "$ENG/resources_product/neutral_print_filters.json" ]; then
    cp "$ENG/resources_product/neutral_print_filters.json" "$dest/neutral_print_filters.product.json"
  fi
  echo "resources -> $dest"
}

build_one iphoneos arm64-apple-ios$IOS_MIN iphoneos
build_one iphonesimulator arm64-apple-ios$IOS_MIN-simulator iphonesimulator
bundle_resources
cp "$ROOT/vendor/spektralab/ios/iphoneos/spektrafilm.metallib" "$ROOT/HalfCam/Resources/engine/spektrafilm.metallib"
echo done
