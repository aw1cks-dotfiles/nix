{ pkgs, skillsSource }:

# liburing headers and the AddressSanitizer/LeakSanitizer runtime are Linux-only
# here. Register this check only for Linux, rather than silently skipping tests.
assert pkgs.lib.assertMsg pkgs.stdenv.hostPlatform.isLinux
  "agent-skills-patches requires Linux (liburing and AddressSanitizer lifecycle checks)";
pkgs.runCommand "agent-skills-patches"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.stdenv.cc
    ];
    buildInputs = [ pkgs.liburing ];
    meta.platforms = pkgs.lib.platforms.linux;
  }
  ''
    set -euo pipefail
    python3 ${./_skills-patch-tests/extract-examples.py} ${skillsSource}

    # Disable elision/optimization so ASAN observes heap-owned coroutine frames.
    c++ -std=c++20 -O0 -g -fno-omit-frame-pointer -fsanitize=address \
      -I. ${./_skills-patch-tests/coroutine-lifecycle.cpp} -o coroutine-lifecycle
    ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 ./coroutine-lifecycle

    # No liburing link: all exercised APIs are real header helpers, and no
    # queue setup/registration/submission or other kernel calls are performed.
    cc -std=c11 -D_GNU_SOURCE -O0 -g -I. \
      ${./_skills-patch-tests/buffer-ring-slots.c} -o buffer-ring-slots
    ./buffer-ring-slots

    mkdir -p "$out"
    printf '%s\n' 'coroutine lifecycle: ASAN and leak detection passed' \
      'provided buffers: distinct slots, publication, wraparound and SQE flags passed' \
      > "$out/results"
  ''
