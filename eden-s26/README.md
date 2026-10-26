# Eden S26: an Eden build tuned for the Samsung Galaxy S26

This is the [Eden](https://git.eden-emu.dev/eden-emu/eden) Nintendo Switch emulator for Android, built from upstream
`master` at `eb88a40a8` (25 Oct 2026). It adds improvements from open pull requests and contributor forks that
haven't been merged yet, plus build settings tuned for the Galaxy S26.

It installs as **"Eden S26"** (`dev.eden.eden_emulator.s26`), next to any official Eden install. That makes A/B
comparison easy. Its data folder is separate too, so you need to point it at your games again and re-import your keys and firmware.

## Your phone: which S26 do you have?

The Galaxy S26 ships with two different chips depending on region:

| | Snapdragon 8 Elite Gen 5 for Galaxy | Exynos 2600 |
|---|---|---|
| Where | US, China, Japan, (Korea varies) | Most other markets incl. Europe |
| CPU | Qualcomm Oryon gen 3, 2 prime + 6 performance cores, no SVE | 1x Arm C1-Ultra + 9x C1-Pro (Armv9.3, SVE2/SME2) |
| GPU | Adreno 840 (Qualcomm driver, or Mesa Turnip) | Xclipse 960 (AMD RDNA-based, Samsung driver) |
| RAM | 12 GB | 12 GB |

To check yours, open Eden S26 and look at the GPU name on the GPU driver screen or in the log: "Adreno 840" means Snapdragon,
"Xclipse 960" means Exynos.

## What's tuned for the S26

| Change | Why |
|---|---|
| CPU target `armv8.6-a+fp16+aes+sha2` (new `s26` build preset) | Official Android builds target the baseline ARMv8.0. This uses the newer instructions both S26 chips share: inline LSE atomics, dot-product, int8 matmul, BF16, FP16 and AES/SHA2. SVE is deliberately left out because the Snapdragon's Oryon cores don't implement it, so one APK runs on both chips. |
| `-O3` instead of `-O2 -g` | Gradle builds Android "release" as RelWithDebInfo, which is `-O2` with debug info. This flavor compiles at `-O3`. |
| ThinLTO (`ENABLE_LTO=ON`) | Lets the compiler inline and optimise across source files in the large `libyuzu-android.so`. |
| No bundled Vulkan validation layer | That layer is only for debugging, so leaving it out makes the APK smaller. |
| Separate application ID | Lets you keep the official build installed for comparison. |
| Per-title default for Pokémon Legends: Z-A | GPU Fence Behavior becomes **Balanced** (Eden's anti-flicker mode) for that title unless you set it yourself. See [LEGENDS-ZA.md](LEGENDS-ZA.md) for the full Z-A guide. |

Eden already ships the Android-side work that matters here: the ADPF performance-hint session, `isGame`/game-mode metadata
for Samsung Game Booster, frame-rate hints, and big/little core placement. Neither S26 chip has little cores, so thread placement
doesn't need changes.

## Unmerged improvements included

From open pull requests on git.eden-emu.dev:

| PR | Author | What it does | Type |
|---|---|---|---|
| [#4399](https://git.eden-emu.dev/eden-emu/eden/pulls/4399) | Lizzie | Removes a ~6 KB copy on every GPU command submission (two inline `small_vector<…, 512>` buffers replaced by moved `std::vector`s) | Performance |
| [#3769](https://git.eden-emu.dev/eden-emu/eden/pulls/3769) | Lizzie | Shader recompiler reuses `stable_vector` pools instead of object pools, which cuts shader-compile stutter | Performance |
| [#4530](https://git.eden-emu.dev/eden-emu/eden/pulls/4530) | xbzk | NCE: ignores duplicate interrupt signals | Performance/stability |
| [#4524](https://git.eden-emu.dev/eden-emu/eden/pulls/4524) | Exverge | NCE: handles guest memory accesses that cross a page boundary (fixed here so it compiles) | Correctness |
| [#4332](https://git.eden-emu.dev/eden-emu/eden/pulls/4332) | Lizzie | Proper instruction-cache invalidation for 32-bit games (dynarmic) | Correctness |
| [#4565](https://git.eden-emu.dev/eden-emu/eden/pulls/4565) | wildcard | Fixes the TotK dark squares on Qualcomm and Turnip drivers | Snapdragon fix |
| [#4528](https://git.eden-emu.dev/eden-emu/eden/pulls/4528) | PavelBARABANOV | Fixes vertex explosions on Turnip when "Optimized Vertex Buffers" is off | Snapdragon/Turnip fix |
| [#4529](https://git.eden-emu.dev/eden-emu/eden/pulls/4529) | xbzk | Fixes the "unknown format 255" crash on the descriptor-buffer path | Stability |
| [#4571](https://git.eden-emu.dev/eden-emu/eden/pulls/4571) | mleo2003 | Fixes a crash or hang when an external display (Samsung DeX) is disconnected mid-game | Stability |
| [#4497](https://git.eden-emu.dev/eden-emu/eden/pulls/4497) | Ahmad | Fixes a multicore crash from stale thread-local data after fiber migration | Stability |
| [#4539](https://git.eden-emu.dev/eden-emu/eden/pulls/4539) | crueter | Audio: guards the biquad filter against a crash | Stability |
| [#3943](https://git.eden-emu.dev/eden-emu/eden/pulls/3943) | wildcard | Fixes Paper Mario: TTYD crashes on Android | Game fix |
| [#4567](https://git.eden-emu.dev/eden-emu/eden/pulls/4567) | PavelBARABANOV / a.kamaltdinov | Fixes Disco Elysium, Civilization VII and Sacred 2 Remaster | Game fixes |
| [#4552](https://git.eden-emu.dev/eden-emu/eden/pulls/4552) | PavelBARABANOV | Supports block-compressed NSZ and XCZ files | Feature |
| [#4546](https://git.eden-emu.dev/eden-emu/eden/pulls/4546) | John / Amicuchu | Texture cache: correct `ReinterpretImage` layout, clamped reinterpret copies, pre-emptive downloads for CPU-read images | Graphics correctness |
| [#4551](https://git.eden-emu.dev/eden-emu/eden/pulls/4551) | xbzk | Shader recompiler tracks bindless texture handles through conditional Phi nodes (missing textures/effects) | Graphics correctness |
| [#4558](https://git.eden-emu.dev/eden-emu/eden/pulls/4558) | PavelBARABANOV / ReiKatari | Viewport Y-flip fix for negative Y scale | Graphics correctness |

From a contributor fork, with no PR open:

| Branch | What it does |
|---|---|
| [simply0001/macro-shared-code](https://git.eden-emu.dev/simply0001/eden/src/branch/macro-shared-code) | GPU macro engine keeps all macro code in one buffer and passes parameters as a span, so there is no vector copy on every macro call |

### Looked at but not included

- **mgranja/fix/am-deliver-focus-state-changes:** a good idea (games flush saves when Eden is backgrounded), but the Android part marks the game "not in focus" on every pause and never restores focus on resume. It also blocks the UI thread for up to ~1.25 s, so games could stay frozen or muted after switching apps.
- **Already upstream:** simply0001/inline-index-bulk and Exverge/sparsevector-zeroregion. Their changes are in `master` already.
- **x86-only:** #4400, #4516 and #3779 only affect the x86-64 JIT and do nothing on a phone.
- **Behaviour trade-offs:** #4512 (async-shader revert: less stutter but more graphical glitches), #4525 (adds an artificial read-speed limit), #4531 (always-on GPU readback).
- **Conflicts:** #4549 (descriptor stride fix) overlaps the Sacred 2 indexed-handle patch from #4567 and would need a manual merge.
- **Too large or still WIP:** #4569 (393-file HLE refactor), #3151 (rewrite of the file I/O layer), #4580 (experimental AOT CPU backend), #4181 (16 KB page rework, draft), #4554 (MSAA cap, draft), and the CamilleLaVey and John experimental branches.

## This build

| | |
|---|---|
| File | `Eden-S26-ZA-v0.0.4-rc2-1080-s26.apk` (21.0 MB, versus 25.0 MB for official v0.2.1 standard). Supersedes `Eden-S26-v0.0.4-rc2-1074-s26.apk`. |
| SHA-256 | `74c83ec152fe1734d090ecc0026db389104725b44f5ddd1835c31823d9690185` |
| Package / label | `dev.eden.eden_emulator.s26` / "Eden S26", min Android 15, target Android 16 |
| Signature | Eden's public debug key (APK signature v2). It can't update an official Eden install; it installs alongside it. |
| Version name | `v0.0.4-rc2-1080-s26`. This is how Eden labels builds from `master`, based on an old upstream tag. The code is master from 25 Oct 2026, newer than v0.2.1. |

Static checks on `libyuzu-android.so`, compared with official v0.2.1 standard:

- **SVE/SME instructions:** 0, so it is safe on both chips.
- **Inline LSE atomics:** about 12,300, versus 34 in the official build (which calls outline helper functions instead).
- **RCpc `ldapr` loads:** 677, versus 0.
- **Page alignment:** 16 KB LOAD alignment, the same as the official build.
- **SHA3 `eor3`:** the only instructions outside the ARMv8.6 baseline are in FFmpeg's CRC code. Upstream FFmpeg only runs that code after a runtime CPU check.
- **JNI symbols:** every Kotlin `external fun` has a matching native symbol, except three that are unresolved in upstream Eden too (the nightly-only update checker, an unused `isFrameInterpolationEnabled`, and one commented-out declaration).

## Install

1. Download `Eden-S26-ZA-v0.0.4-rc2-1080-s26.apk` and open it. Allow "Install unknown apps" for your browser or file manager when asked.
2. Launch **Eden S26**, then add your `prod.keys`, firmware and games folder (same steps as official Eden).
3. Recommended:
   - **Snapdragon S26:** use the system driver. If a Mesa Turnip build with Adreno 8xx support is available, load it from Eden's GPU driver manager and compare.
   - **Exynos S26:** use the system driver.
   - Keep "Use asynchronous shaders" on. Start at 1x resolution and increase it once a game runs well.
   - Add Eden S26 to Samsung Game Booster, and set its battery usage to "Unrestricted" so it isn't throttled or killed in the background.

## Caveats

- **Untested on a real phone:** this build was compiled and checked statically, but not run on an S26 (none was available).
  - If it closes immediately at launch, that would most likely be the CPU target. Please report it, and keep using official Eden in the meantime.
- **Expected gains are modest:** a few percent from compiler tuning, less GPU-thread overhead, and less shader stutter. GPU-bound games won't change much. The bigger differences are the bug and crash fixes listed above.
- **Package-name boost:** official "Eden Optimized" uses the Genshin package name (`com.miHoYo.Yuanshen`) to trigger vendor game boosts. This build doesn't. If the official Optimized build runs a game faster on a Snapdragon S26, that boost is the reason, and a spoofed variant of this build can be made.

## Rebuild

`./build-s26.sh` clones Eden at the pinned commit, applies `patches/` and runs Eden's own Android CI script with
`-t s26`. The **Build Eden S26** GitHub Actions workflow does the same and uploads the APK. It can be triggered manually once
this folder is on the default branch.

`sandbox/` holds the helpers used to build without GitHub release downloads:
- `build-ci-deps.sh` rebuilds Eden's prebuilt FFmpeg, SDL3 and OpenSSL with the same crueter-ci scripts.
- `offline-cpmutil.patch` makes CPM fall back to `git` for source archives.

Normal builds don't need either.
