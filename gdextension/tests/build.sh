#!/bin/sh
# Builds and runs the core's own cases (world_runner.cpp) under the constraints Unreal compiles plugins with:
# no exceptions, no RTTI, shadowing and implicit narrowing as errors, C++17.
# It reads the cases shipped with the plugins and compiles the Unreal plugin's FRule as the independent reference.
set -e
cd "$(dirname "$0")"
MB=../../engines/unreal/MarchingBlocksPaint/Source/MarchingBlocksPaint
${CXX:-g++} -std=c++17 -O2 -fno-exceptions -fno-rtti \
  -Wall -Wextra -Wshadow -Wconversion -Wsign-conversion -Werror \
  -I"$MB/Public" \
  world_runner.cpp ../src/noyau/world.cpp "$MB/Private/MBCore/MBJson.cpp" "$MB/Private/MBCore/MBRule.cpp" \
  -o world_runner
./world_runner "${1:-../../engines/unreal/MarchingBlocksPaint/Tests}"
