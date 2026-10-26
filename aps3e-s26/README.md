# aPS3e for Galaxy S26

A build of [aPS3e](https://github.com/aenu1/aps3e) (the Android port of RPCS3) tuned for the Galaxy S26.
It works on both S26 variants from one APK:

| | Snapdragon variant | Exynos variant |
|---|---|---|
| SoC | Snapdragon 8 Elite Gen 5 for Galaxy | Exynos 2600 |
| CPU | 2x Oryon-L + 6x Oryon-M (Oryon v3) | 1x Lumex C1-Ultra + 9x C1-Pro (Armv9.3) |
| GPU | Adreno 840 (Qualcomm driver or Turnip) | Xclipse 960 (RDNA, Samsung driver) |

Everything that differs between the two is detected at runtime; the static code targets what both chips implement.

- **Base:** upstream `main4` at `c6ca182` ("2.43", 2026-10-05). That branch is the real mainline: the
  repository's default branch, `main2`, stopped at 1.38 in April and is 41 commits behind it.
- **Package:** `aenu.aps3e.s26`, so it installs next to the official app instead of replacing it. It has its own
  data folder: copy firmware, games and saves over as you would for a fresh install.
- **APK:** see [Releases / the file sent with this change](#the-apk).

## What changed and why

Ten patches on top of upstream (`patches/`, `git am` order). In order of expected impact:

### 1. Compiler: -O3, Armv8.6-A, ThinLTO, clang 21 (`0007`)

Upstream release builds are `RelWithDebInfo`: `-O2 -g -march=armv8-a`, no LTO, on the Android Gradle plugin's
default NDK (r27, clang 18). Desktop RPCS3 ships `-O3` with LTO. This build uses:

- `-O3`, no debug info (it was stripped from the APK anyway).
- `-march=armv8.6-a+aes+sha2` for every native library. Both S26 chips implement it (Oryon v3 is Armv9.2-class,
  Lumex C1 is Armv9.3). The biggest single effect: at `armv8-a` every `std::atomic` operation compiles to a
  *call* into the outline-atomics helpers (`bl __aarch64_ldadd4_acq_rel`); at v8.6 it is one inline LSE
  instruction. RPCS3 leans on atomics everywhere (reservations, locks, wait queues). It also lets the compiler
  use RCPC (cheaper acquire loads), LSE2 (single-instruction 128-bit atomic loads/stores) and the v8.6 SIMD
  extensions.
  SVE, SME and MOPS are left out on purpose: whether the kernel enables them differs between the two variants.
- ThinLTO on the emulator core and the final `libe.so`, as desktop RPCS3 does.
- NDK r30 (clang 21) instead of r27 (clang 18): newer codegen and it knows the Oryon and Cortex-X925 models.
- Upstream also re-added `-march=armv8-a` inside RPCS3's own CMake, later on the command line, which would
  silently undo any top-level choice. Fixed for Android.

### 2. RSX idle sleep (`0005`, from the [Odin 3 fork](https://github.com/HamzaDevz/aps3e/tree/odin3))

When the game is busy on the PPU the RSX thread spins on an empty command FIFO with `yield()`. On Android that
yield returns immediately when nothing else is runnable on the core, so the RSX thread pins a **prime core at
100%** doing nothing. The Odin 3 fork measured the stock build on a Snapdragon 8 Elite at 104-105 °C with the RSX
thread at 97%. On a phone that heat comes straight back as throttling of the PPU/SPU threads.

Now, once the FIFO has been idle for one slice, the RSX thread sleeps in slices (100 µs by default) and services
flips/interrupts right after each sleep. New setting: **Settings → Video → RSX Idle Sleep** (0 restores the old
spinning behaviour).

### 3. Persistent Vulkan pipeline cache (`0004`, from [mercurious's fork](https://github.com/mercurious/aps3e), upstream PR #122)

`main4` creates a `VkPipelineCache` but starts it empty on every launch and throws it away on exit, so the
Adreno/Xclipse driver compiles every pipeline from scratch on every boot of a game. It is now loaded from and
saved to the game's cache folder (`vk_pipeline_cache.bin`): after the startup shader-cache load and on exit
(the early save matters because Android usually kills the process rather than letting it shut down). Data
written by another GPU or driver, e.g. after switching to a Turnip driver, is detected and discarded.
Second and later launches of a game get through shader loading much faster and stutter less.

This also fixes a latent bug: the cache calls went to the system Vulkan loader instead of the active driver,
which bypasses a custom (adrenotools/Turnip) driver.

### 4. JIT targets exactly what the S26 reports (`0002`, `0003`)

The PPU/SPU recompilers generate the hot code at runtime with LLVM. Upstream picks a CPU model and toggles only
five features. On the S26 that is off in both directions:

- Exynos 2600 is detected as `c1-pro`, which in LLVM implies MOPS, MTE, RCPC3 and SME2 whether or not Samsung's
  kernel enables them. MOPS in particular faults if the kernel has not switched it on.
- Snapdragon's Oryon v3 maps to `oryon-1` (or, if Qualcomm gave it a new part number, to a 2020 `cortex-a78`
  fallback), which under-reports the core.

The JIT now reads the kernel's HWCAP bits and enables exactly LSE/LSE2/LSE128, RCPC/RCPC-immo/RCPC3, CRC, AES,
SHA2, FP16, FHM, BF16, JSCVT, FCMA, FlagM/FlagM2, FRINT, MOPS, CSSC and MTE as reported, with SME kept off. Unknown Qualcomm
parts map to `oryon-1`. The C1 cores were also missing from the app's CPU tables, so the "LLVM CPU" picker offered
"Unknown", an invalid LLVM CPU that silently drops to generic code.

The chosen target is logged once: look for `LLVM: Target CPU '...' with host features ...` in the log.

### 5. Thread priorities that actually apply on Android (`0010`)

RPCS3 raises the RSX and audio threads and lowers its background PPU/SPU compile workers, but on Linux that
call is a no-op (`SCHED_OTHER` has a single priority). Android lets an app renice its own threads, so these now
map to nice -4 / +4: frame-critical and audio threads win contention, and background compilation stops taking an
equal share from the game threads.

### 6. Xclipse support (`0006`)

RPCS3 did not know Samsung's driver: "Unsupported device" and Intel-tuned compute settings for its RSX compute
shaders. Xclipse is RDNA hardware, so it now gets the AMD wave64 settings. (Adreno and Xclipse were also missing
from a switch that logs "Unknown driver vendor!" on every render target when strict rendering is off.)

### 7. 60 Hz display while a game runs (`0008`)

PS3 games present at most 60 fps, but the S26's panel kept refreshing at up to 120 Hz for the game. The emulator
surface now asks for 60 Hz (only when the switch is seamless). Same frames, less display and composition power.

### 8. Smaller things

- 6 LLVM compile threads instead of 4 (`0009`): faster PPU module compilation and SPU cache building on an 8-10
  core SoC with 12 GB of RAM.
- Builds on case-sensitive filesystems (`Loader/iso.cpp` is referenced as `ISO.cpp`), with NDK r28+ (a missing
  include) and with clang 21 (a chained comparison in FFmpeg's unused `v360` filter, fixed as upstream FFmpeg
  did) (`0001`).

## Fork survey

All 73 forks of `aenu1/aps3e` (as of 2026-10-26) were checked, plus all upstream pull requests: every branch of
every fork was compared against all four upstream branches (`main`, `main2`, `main3`, `main4`). 54 forks contain
only upstream history. The 19 that carry commits found in no upstream branch:

| Fork / branch | Unmerged work | Verdict |
|---|---|---|
| HamzaDevz `odin3` | RSX idle sleep, database config at boot, Odin 3 bench tools | **RSX idle sleep included** (#2). DB-config-at-boot is a compatibility change for specific games, not performance; left out |
| mercurious `vk-pipeline-cache` (PR #122) | Persistent `VkPipelineCache` | **Included** (#3), reworked for main4 |
| mercurious `pr-18844-backport` (PR #127) | Descriptor-pool autogrow (RPCS3 #18844) | Already in main4 |
| mercurious `etk-tune`, `cloud-forge`, `shader-cache-manager` | GT5 road-flicker fix, pad record/replay, shader-cache export, build tooling | Game-specific fixes and features, not performance; based on the old 0.0.40/main2 line |
| makolg `fix-spu-ls-alias` (PR #151) | SPU LLVM local-store aliasing fix | Already in main4 |
| nikitaolenych-byte | Big-core pinning for PPU threads, zstd shader cache, Vulkan 1.3 instance | Not included: pinning every PPU thread to the 2 prime cores starves games with more than two busy PPU threads (Android's scheduler already places hot threads on big cores); zstd costs CPU on fast UFS 4 storage |
| ytcarphantom | `-O3 -flto -ffast-math -march=armv8.2-a` | Direction taken (#1) without `-ffast-math`, which breaks the PS3's floating-point and NaN semantics |
| jch0029987-glitch `aps3e-mali` | Mali/Pixel 7 tuning, FPS overlay, "turbo" toggle | Mali-specific; the S26 has no Mali GPU |
| o-bin, sunnydhar | Mali-G57 workarounds and their compile fixes | Mali-specific (o-bin's are already upstream) |
| B11-Health (19 branches) | GTA IV/V SPURS/Bink/GCM debugging, CI canaries | Instrumentation for one game; the SPU "inline ret" change contradicts upstream RPCS3's working ARM64 code and could not be verified here |
| davidhbui `main4` | Texture dumping/replacement | Feature, not performance |
| lxyongit `app` | UI rework, async shader mode default | UI; shader-mode change is a different trade-off, not a speed-up |
| christopher377526, Rorgu, aziz728228, ah124med, mohamed-saiff (PR #103), YouDontNeedToKnow (PR #80) | CI workflows, `build.gradle` tweaks | Build plumbing only |
| ah124med (PR #24) | Raises the minimums of some settings sliders | UI ranges, not performance |
| HAKAMIQ, JaGNUar, xowex777, SeaNaxxx | README, contributor refresh, test package name, dependabot | Nothing functional |

## Not tested on a device

This build was compiled and checked here, but I have no Galaxy S26 to run it on. Everything above is reasoned
from the code, the forks' measurements and the two chips' specifications, not measured on your phone. To compare,
the untouched upstream 2.43 can be built from the same tree with `build.gradle.bak`; or keep the official app
installed side by side (different package) and compare the same scene with the performance overlay.

Things worth checking on the device:

- The log line `LLVM: Target CPU 'oryon-1'` (Snapdragon) or `'c1-pro'` (Exynos) with its feature list.
- `Saved Vulkan pipeline cache (N bytes)` after the first boot of a game, and `Loaded Vulkan pipeline cache`
  on the next one.
- If a game stutters or runs slower than in the official app, set **RSX Idle Sleep** to 0 first: it is the one
  change that trades a little RSX wake-up latency for heat.

## The APK

Build in progress; the APK and its checksum are added here once it is finished.

## Building

```sh
export ANDROID_HOME=/path/to/sdk   # platforms;android-35, build-tools;35.0.0, ndk;30.0.16248370, cmake;3.31.5
scripts/build.sh [work-dir]        # clones upstream at c6ca182, applies patches/, runs gradle assembleRelease
```

JDK 17+ and Gradle 8.10+ are needed. A cold build takes about 1.5 h on 4 cores and ~20 GB of disk. Set
`APS3E_KEYSTORE`, `APS3E_KEYSTORE_PASS`, `APS3E_KEY_ALIAS` and `APS3E_KEY_PASS` to sign with your own key;
otherwise the debug key is used.
