#!/bin/zsh
# Compiles MemoryLogic.swift with Tests/main.swift and runs the checks.
set -e
cd "$(dirname "$0")"
mkdir -p build
swiftc MemoryLogic.swift Tests/main.swift -o build/memorybar-tests
build/memorybar-tests
rm -rf build
