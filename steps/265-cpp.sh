LLVM_VERSION=23

register_step cpp \
    --desc "C/C++ toolchain: cmake, ninja, ccache, gdb, LLVM $LLVM_VERSION (clang, clangd, clang-tidy), cross compilers" \
    --group dev --root --needs prereqs \
    --provides cmake ninja ccache gdb clangd clang-tidy clang-format gcovr doxygen

step_cpp() {
    log "Ensuring the LLVM $LLVM_VERSION apt repo is set up"
    ensure_apt_key https://apt.llvm.org/llvm-snapshot.gpg.key /usr/share/keyrings/llvm.asc
    ensure_apt_list /etc/apt/sources.list.d/llvm.list \
        "deb [signed-by=/usr/share/keyrings/llvm.asc] https://apt.llvm.org/trixie/ llvm-toolchain-trixie-$LLVM_VERSION main" \
        "apt.llvm.org/trixie"

    log "Installing C/C++ toolchain"
    apt_install \
        build-essential cmake ninja-build ccache gdb pkg-config \
        autoconf autoconf-archive automake libtool bison flex nasm \
        clang-$LLVM_VERSION clangd-$LLVM_VERSION clang-format-$LLVM_VERSION clang-tidy-$LLVM_VERSION \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
        gcc-mingw-w64-ucrt64 g++-mingw-w64-ucrt64 wixl \
        gcovr doxygen cmake-format rsync zstd

    local tool
    for tool in clang clang++ clang-format clang-tidy clangd; do
        sudo update-alternatives --install "/usr/bin/$tool" "$tool" "/usr/bin/$tool-$LLVM_VERSION" "${LLVM_VERSION}0"
    done
}
