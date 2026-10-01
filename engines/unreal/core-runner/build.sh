#!/bin/sh
# Builds and runs the conformance runner with the constraints Unreal compiles plugins under:
# no exceptions, no RTTI, shadowing and implicit narrowing as errors. C++17, the oldest Unreal 5 allows.
set -e
cd "$(dirname "$0")"
SRC=../MarchingBlocksPaint/Source/MarchingBlocksPaint
${CXX:-g++} -std=c++17 -O2 -fno-exceptions -fno-rtti \
  -Wall -Wextra -Wshadow -Wconversion -Wsign-conversion -Werror \
  -I"$SRC/Public" \
  runner.cpp "$SRC/Private/MBCore/MBJson.cpp" "$SRC/Private/MBCore/MBRule.cpp" "$SRC/Private/MBCore/MBTools.cpp" "$SRC/Private/MBCore/MBFrame.cpp" \
  "$SRC/Private/MBCore/MBWorldFile.cpp" "$SRC/Private/MBCore/MBShapes.cpp" \
  -o runner
./runner "${1:-../MarchingBlocksPaint/Tests}"
