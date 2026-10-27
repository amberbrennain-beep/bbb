# Pokémon Legends: Z-A on Eden S26

Title ID `0100F43008C44000`. This page covers what the Eden S26 build changes for this game, the settings to use on a Galaxy
S26, and the mods that lower its GPU cost. The Switch 1 version of the game targets 30 fps and uses dynamic resolution; on
real hardware it drops into the 20s in Lumiose City, so the game itself is heavy before emulation overhead is added.

## What's in the build for this game

| Change | Why it matters here |
|---|---|
| **Per-title default: GPU Fence Behavior = Balanced** | Eden's anti-flicker fence mode ([#4004](https://git.eden-emu.dev/eden-emu/eden/pulls/4004)). The Android default is "Default", which follows the Low accuracy level and signals fences immediately; that is the mode that produces texture and shadow flicker. The build applies Balanced for this title only, and only if you haven't set GPU Fence Behavior yourself (globally or per game). It costs a little performance. |
| [#4546](https://git.eden-emu.dev/eden-emu/eden/pulls/4546) texture-cache fixes (John / Amicuchu) | Correct image layout in `ReinterpretImage`, clamps reinterpret copies to the source size (stops garbage rows), and queues pre-emptive downloads for images the CPU reads back. These are the paths behind corrupted or stale textures. |
| [#4551](https://git.eden-emu.dev/eden-emu/eden/pulls/4551) bindless-handle tracking through conditional Phi nodes (xbzk) | Fixes missing textures/effects when a shader picks a texture handle inside an `if`. |
| [#4558](https://git.eden-emu.dev/eden-emu/eden/pulls/4558) viewport Y-flip fix (PavelBARABANOV / ReiKatari) | Correct viewport when a render pass uses a negative Y scale. |
| Already in upstream master | The Z-A "vertex explosion" fix (`vk_query_cache`, transform-feedback begin without counters) and the TotK dark-squares fix for Qualcomm/Turnip ([#4565](https://git.eden-emu.dev/eden-emu/eden/pulls/4565), included). |
| The S26 build itself | `-O3`, ThinLTO and the ARMv8.6 CPU target all help a CPU-bound game like this one; so do the NCE fixes and the GPU command/macro copy removals. |

Not included: [#4549](https://git.eden-emu.dev/eden-emu/eden/pulls/4549) (descriptor-stride fix) conflicts with the Sacred 2 patch already in the build;
[#4575](https://git.eden-emu.dev/eden-emu/eden/pulls/4575) (D24 depth emulation on non-NVIDIA GPUs, which may affect shadow precision on Adreno) is still a WIP draft.

## Settings to use

Set these **per game** (long-press the game → Properties), so they don't affect other titles.

| Setting | Value | Reason |
|---|---|---|
| Graphics → Resolution | **1x** | The game already renders up to 1080p docked. Upscaling costs frame rate for little visible gain on a phone screen. |
| System → Docked Mode | **Off** (handheld) | Renders at the handheld resolution (up to 720p) instead of 1080p: roughly half the pixels. Turn Docked on only if handheld at 1x is already stable. |
| Graphics → GPU Accuracy | **Normal** if textures still flicker, otherwise leave at Low | Normal costs some performance but fixes flicker that fences alone don't. High is too slow on a phone. |
| Advanced → GPU Fence Behavior | leave on **Default** | The build turns this into Balanced for this title. Set it to **Accurate** manually if flicker remains. |
| Hacks → Use asynchronous shaders | **Off** while testing flicker | Async shaders skip draws whose shader isn't compiled yet, which looks like flicker/pop-in. Turn it back on once the shader cache is warm if stutter bothers you more. |
| Hacks → Skip CPU Inner Invalidation | **Off** | It helps CPU-bound games, but is known to cause glitches. Try it last, on its own, and revert if anything flickers. |
| Extensions → Extended Dynamic State | **0 (Disabled)**, the Android default | Users with Adreno GPUs report "blinking" in Lumiose City with EDS enabled. |
| System → GPU Clocks | **Boost** (default) | Prevents the game's dynamic resolution from dropping. If frame rate matters more than sharpness, set **Default** so the game lowers its own resolution under load. |
| Graphics → VSync | **FIFO** or **Mailbox** | Keeps frame pacing even. Immediate tears. |
| GPU driver (Snapdragon) | system driver first; try a Mesa Turnip build with Adreno 8xx support if available | Turnip often fixes flicker the stock Qualcomm driver shows. The official Eden "Optimized" build note applies too: the Genshin package spoof can raise Snapdragon clocks. |
| Game update | **2.0.2** | Required for the mods below, and newer game versions carry Game Freak's own performance fixes. |

The first run through Lumiose will stutter while the shader cache fills. Judge frame rate on the second visit.

## Mods that lower the GPU cost

Fl4sh9174 maintains an exefs patch pack for this game: [Switch-Ultrawide-Mods, "Pokémon Legends Z-A \[0100F43008C44000\]\[mods\].zip"](https://github.com/Fl4sh9174/Switch-Ultrawide-Mods).
Each folder in the zip is one mod (a folder with an `exefs/` directory inside). On Android: unzip the pack on the phone, open the game in Eden S26 → **Add-ons** → install, and pick one mod folder at a time (the picker needs a folder that contains `exefs/`). Then tick the mods you want in the same Add-ons list. Patches exist for game versions 1.0.0 to 2.0.2; Eden picks the file matching your installed update.

Recommended for a phone (each removes GPU work):

- **Disable FXAA**: removes the post-process anti-aliasing pass.
- **Disable DOF**: removes depth-of-field blur.
- **Reduce Bloom**: removes the bloom pass.

Leave alone:

- **Static 60 FPS / Dynamic 60 FPS**: the game needs twice the CPU time per second; on a phone this means slow-motion or audio issues. The game's own 30 fps cap is the right target.
- **4K Shadows**: raises the shadow map to 4096², which costs GPU time and has been reported to crash. Lower shadow resolution is not offered.
- **Level of Detail**: raises LOD bias and anisotropic filtering, which costs performance.

The pack has no licence file, so it isn't copied into this repository; download it from the author.

## If it still flickers

Try these one at a time, in order, each on its own:

1. GPU Fence Behavior: **Accurate**.
2. GPU Accuracy: **Normal**.
3. Snapdragon: switch between the system driver and a Turnip driver.
4. Delete the game's shader cache (game menu → Clear shader cache) and let it rebuild.
5. Report what fixed it. If the fence change or the accuracy level is what fixed it, that can become a per-title default in the next build.
