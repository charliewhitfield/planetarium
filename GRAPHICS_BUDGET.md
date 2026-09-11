# Planetarium Graphics Budget

What each candidate graphics option would buy back on a weak GPU, and what it would cost on
screen. Every figure was measured in the running app (Planetarium v0.2.1.dev, Godot 4.7.2) on
2026-09-10, on the Intel UHD integrated graphics that stands in for the web app's least capable
visitors, with a GTX 1650 Ti alongside.

This is the Markdown copy of an illustrated report. The illustrated version adds a frame-time
chart and the screenshot comparisons that the figure notes below summarize.

**Relief** is the GPU time saved, as a share of that scene's frame. **Visual cost** is the change
in the rendered image, measured in 8-bit display codes on screenshots taken before and after.


## The short version

1. On the Intel iGPU with the **Compatibility** renderer, which is the web app's renderer,
   ordinary views run at 20-35 fps. **Any view with an atmosphere runs at 1-2 fps.** The limb
   shell alone is 75-95% of those frames: Earth close up takes ~490 ms and Titan ~900 ms.
2. The four big levers, in order:
   - **Atmosphere quality.** A reduced tier saves 22-38% with no visible change; off saves
     76-95%.
   - **3D render scale.** 75% saves 17-28%; 50% saves 30-66%.
   - **The renderer itself, on desktop.** Compatibility is 1.4-8x faster than Forward+ on the
     iGPU.
   - **Star-catalogue depth.** V 11 saves 29-31% in dark-sky views; V 9.5 saves 43-52%.
3. Of the existing options:
   - **Shadow Resolution** matters on Forward+. 16384 adds up to 49 ms a frame even on the GTX,
     and 2048 in place of the default 8192 saves 27-39% of an iGPU frame.
   - **MSAA** is a modest lever: off saves 5-13% on the iGPU against 2x, and 5-23% on the GTX.
   - **FXAA and TAA** cost rather than save.
   - **Physical Light** saves nothing, and turning it off costs up to 35%.
4. **The web may not load at all on these machines.** Through ANGLE on the iGPU, which is
   Chrome's path on Windows, the limb shader takes 283 s to compile and 50 s for every further
   variant. That is far past Chrome's roughly 10-second GPU watchdog.
5. Several costs buy nothing visible and can go with no option at all: the Milky Way and most of
   the star field in any lit-body view, the limb shell's disc-interior fragments, and sphere
   detail beyond 128x64. Together they are worth 10-30% in most views and far more at Earth and
   Titan.


## Where the frame goes today

GPU time per frame, in ms, at 1920x1080. The budgets are 16.7 ms for 60 fps and 33.3 ms for 30 fps.

| View | Intel UHD, Compatibility | Intel UHD, Forward+ | GTX 1650 Ti, Compatibility | GTX 1650 Ti, Forward+ |
|---|---:|---:|---:|---:|
| Earth fills the screen | 490 | 4112 | 26.2 | 18.0 |
| Earth at 3 radii | 689 ✱ | 1802 | 13.9 | 9.8 |
| Titan at 3 radii | 900 | 1251 | 19.3 | 29.2 |
| Saturn at 45° | 41.2 | 263 | 5.1 | 5.2 |
| Jupiter's moons | 28.6 | 65.7 | 2.6 | 4.0 |
| Sun close-up | 44.0 | 73.3 | 4.8 | 12.6 |
| Whole system, dark sky | 30.8 | 64.2 | 13.7 | 20.0 |
| Asteroid belt | 33.2 ✱ | 61.2 | 17.0 | 23.7 † |

✱ That run hit the driver slow state described under *Caveats*, so the value reads high.
† That scene's baseline drifted during its run.


## How this was measured

**Machine and setup.**

- Dell XPS 15 9500: i7-10875H, Intel UHD Graphics (Comet Lake GT2, 24 EU) and GTX 1650 Ti,
  driver 581.95.
- Godot 4.7.2, window at 1920x1080, sim paused, v-sync off, frame rate uncapped.

**Timing.** GPU time is the main viewport's timestamp-query interval: GL timestamps on
Compatibility, Vulkan on Forward+. Each figure is the median of at least five frames, taken after
a warm-up that absorbs any shader compile.

**Toggling options.** Each option was toggled in the running app by a scratch Assistant probe
suite, and reverted before the next. Toggles were settings, Environment and Viewport properties,
node visibility, shader uniforms, runtime shader swaps and star-mesh rebuilds.

**Reaching the Intel iGPU.** Godot exports `NvOptimusEnablement = 1`, so the Intel runs used a
copy of the executable with that export cleared. Windows' default then puts OpenGL on the iGPU.
Vulkan used `--gpu-index 0`.

**The eight views.**

- Earth filling the screen, day side, 1.6 radii
- Earth at 3 radii
- Titan at 3 radii, with its haze ring
- Saturn at 45°, with rings and about 40 moon orbits
- Jupiter's moon system from above
- The Sun at 3 radii
- The whole system in the dark-adapted sky (`VIEW_SYSTEM`)
- The asteroid belt with its 70k points (`VIEW_ASTEROIDS`)

HUDs were left at their defaults and the 2D GUI was hidden.

**Screenshot comparisons.** The same pose is captured before and after each change. Reported as
the mean and 99th-percentile absolute difference per pixel, and the share of pixels that move by
more than 2 or 8 codes.


## All options, ranked

The ranking is by how much a weak GPU gets back for how little it gives up on screen. Relief is
given for the Intel iGPU on Compatibility (the web's case) and for the GTX 1650 Ti. Ranges span
the views where an option acts; views where it does nothing are left out rather than averaged in.
Intel figures for the atmosphere views come from runs in the driver's normal state.

### High relief

| # | Option | Relief, Intel iGPU | Relief, GTX 1650 Ti | Visual cost | Verdict |
|---|---|---|---|---|---|
| 1 | **Atmosphere quality**: Full / Reduced / Off. Runtime shader swap, or restart. | Reduced -22 to -38%; Off -76 to -95% (atmosphere views) | The shell is 15-39% of the frame | Reduced: none visible. Up to 15 codes on 1-2% of pixels, confined to the limb band. Off: no air at all, and Titan loses its identity. | Add. Default to Reduced on integrated GPUs and the web. |
| 2 | **3D render scale**: 100 / 85 / 75 / 50%. Runtime. FSR 1 on Forward+. | 75%: -17 to -28%; 50%: -30 to -66% | 75%: -13 to -36%; 50%: -25 to -64% | Soft lines and HUD text. At 50%, orbit lines turn chunky, and the star field coarsens because star size follows render height. | Add. On a 2x hi-DPI web canvas, 50% simply restores 1x cost. |
| 3 | **Renderer** (desktop): Auto / Forward+ / Compatibility. Restart. | Compatibility 1.4-8x faster than Forward+ | Mixed: Compatibility faster in 5 of 8 views | Compatibility loses mouse-over identification of orbit lines and asteroids, FXAA and TAA, and local shadow maps. The picture itself matches. | Add, with Auto choosing Compatibility on integrated GPUs. |
| 4 | **Star catalogue depth**: all (V 15) / V 11 / V 9.5. Restart, or a 0.3-1.1 s rebuild. | V 11: -17 to -29%; V 9.5: -26 to -43% (star-heavy views) | V 11: -28 to -31%; V 9.5: -44 to -52% | None in lit-body views, where exposure hides faint stars. In dark-sky views, V 11 dims the diffuse star glow (about 7 codes over a third of the sky) and V 9.5 is visibly sparser. | Add as a restart option. It also saves memory and load time. |
| 5 | **Shadow resolution** (existing; Forward+ only in the Planetarium) | vs 8192 on Forward+: 2048 -27 to -39%; 16384 +18 to +88% | 2048: -1 to -10%; 16384: +28 to +387% | Spacecraft-scale self-shadowing only. Eclipses and ring shadows are analytic and unaffected. | Keep. Drop 16384, add Off, and default to 4096. |

### Moderate relief

| # | Option | Relief, Intel iGPU | Relief, GTX 1650 Ti | Visual cost | Verdict |
|---|---|---|---|---|---|
| 6 | **MSAA** (existing): off / 2x / 4x / 8x, default 2x | Off: -5 to -13%; 4x: +9 to +11% | Off: -5 to -23%; 4x: +3 to +15% | Stair-stepped orbit lines; the dense ring-plane orbits shimmer. Planet rims are already anti-aliased by the shaders' own PSF. | Keep. Consider Off as the web default. |
| 7 | **Glow**: on / off. Runtime. | -12 to -16% in light views; ~0 in atmosphere views | -1 to -16%; Forward+ -5 to -29% | Small. No bloom on blown extended sources (up to 58 codes beside a bright limb). On Compatibility, off also restores the dimmest codes. | Add. |
| 8 | **Star glare wing**: full / off. Runtime. | -11 to -25% (star-heavy views) | -15 to -16%; Forward+ -24% | No change in lit-body views. In dark-sky views half the sky moves (mean 10.5 codes): halos go, and the faint end moves about 3 mag brighter. | Fold into a "Star field" setting with catalogue depth. |
| 9 | **Milky Way background**: on / off. Runtime. | -10 to -17% | -5 to -13% | None in any lit-body view, where exposure already puts it below one code. In dark-sky views the Milky Way goes (8 codes on 62% of pixels). | Skip it automatically below one code (see *Free wins*). A user toggle is optional. |
| 10 | **Cloud decks**: on / off. Runtime. | -6 to -7% (Earth views) | -22 to -26%; Forward+ -22 to -38% | Large: Earth and Neptune lose their clouds (19% of pixels in an Earth view). | Lowest tier only. |
| 11 | **Frame-rate cap**: 30 / 60 / uncapped. Runtime. | Up to -50% energy when a frame beats the cap | Same | Motion smoothness only. No help when a frame already misses the cap. | Add for laptops and batteries. It's a one-liner. |

### Low relief, or better made automatic

| # | Option | Relief, Intel iGPU | Relief, GTX 1650 Ti | Visual cost | Verdict |
|---|---|---|---|---|---|
| 12 | **Sphere mesh detail**: 256x128 today. Restart, or runtime. | 128x64: -13 to -27%; 64x32: -17 to -38% | 128x64: -10 to -27%; 64x32: -16 to -34% | 128x64 is indistinguishable, with 0.16 px of silhouette error on a screen-filling disc. 64x32 shows rim artefacts. | Not an option: make 128x64 the default, or add distance LOD. |
| 13 | **Sun surface detail** (sunspot cells). Runtime uniform. | -36% (Sun close-up only) | Not measured | No sunspots. | Automatic LOD by disc size. |
| 14 | **FXAA** (existing; Forward+ only) | +0 to +6% | +1 to +16% | A benefit: smoother lines, at a slight blur. | Keep. |
| 15 | **TAA** (existing; Forward+ only, experimental) | +10 to +27% | +4 to +39% | Ghosts orbit lines, which are positioned in the vertex shader. | Remove, or keep it hidden. |
| 16 | **Physical light** (existing) | Off: -5 to +26% | Off: +0 to +35% | Changes the whole look. Off keeps the unmetered exposure, so every star draws at full size, which is why it costs. | Not a performance setting. Move it to another section. |
| 17 | **HUD layers and body PSF quads**: orbits, labels, symbols, asteroid points | 0 to -5% | 0 to -5%; asteroid points -16% at the belt | Content, not quality. | No option needed; already user-controlled. |


## Atmospheres

On the iGPU the limb shell dominates the frame. Hiding it takes Earth-fill from ~490 to 116 ms
and Titan from ~900 to 60 ms. Zeroing the optical depths as well, so the surface and cloud shaders
stop compositing air, brings Earth to 97 ms and Titan to 40 ms. What's left is the surfaces, the
clouds, and a 22-24 ms floor of stars, sky and HUD. On the GTX the shell is a much smaller share
(15-22% at Earth, 39% at Titan on Forward+), so this is overwhelmingly an integrated-GPU problem.

Three knobs already in `_atmosphere.gdshaderinc` reduce the cost:

- **A lower-order along-ray quadrature.** A padded 4- or 3-node Gauss-Legendre table is a valid
  rule for both GL6 loops.
- **A lower cap on the beyond-limb ring taps.** `atm_ring_max_taps` accepts any value.
- **Dropping the detached layer.** `atm_layer_tau` = 0.

Each was measured on the iGPU, with the screenshots diffed against the shipped render:

| Variant | Earth fill | Titan | Visual difference vs shipped |
|---|---:|---:|---|
| 4-node quadrature | -19% | -16% | Max 2 codes (Earth), 15 (Titan); 0.4% of Titan's pixels differ by more than 2 |
| 3-node quadrature | -23% | -26% | Max 3 / 21 codes |
| **4-node + 2 ring taps** | **-25%** | **-38%** | 1.2% / 1.8% of pixels differ by more than 2 codes, max 12 / 15, all in the limb band |
| ... plus early interior discard | -22 to -37% | -35 to -39% | Identical to the row above (the discard is exact) |
| Detached layer off | -9% | -33% | Titan's outer haze shell disappears |
| 1 ring tap (diagnostic) | -19% | -52% | Not assessed |
| Limb shell off | -76% | -94% | No limb, no haze ring |
| All air off | -80% | -95% | 87% of Earth's pixels change |

*Figure notes (illustrated version).* At 2x on Titan's limb, the shipped shader, 4-node, 4-node + 2
taps and 3-node are indistinguishable. Layer-off loses the outer haze band, and all-air-off loses
everything. Seen whole, Titan in this app is its haze. That is why Off is a real loss there, and
why Reduced is the tier to default to.

### Why the shell costs so much on Intel, and the exact fix

Most of the shell's fragments lie over the disc interior. There they return nothing: they
discard, and the surface and cloud shaders composite that air themselves. On the Intel driver,
those fragments are not cheap.

- **Discard first.** A limb shader that discards at its very first statement still costs 249 ms
  at Earth-fill, against 116 ms for a shader whose body is dead code.
- **Branch around the body.** An explicit `if` around the whole body recovers only 3-6%.
- **Early discard.** An exact interior discard before any setup recovers only 0-10%.
- **Unrolling doesn't help.** Making the loop bounds constants again, so the loops unroll, is
  12-22% slower.

The driver evidently runs much of this large program for pixels that contribute nothing.

What does work is not generating those fragments at all. Draw the limb shell as a camera-facing
annulus around the silhouette instead of a full sphere. `atm_limb()` needs only the view ray,
which a billboard ring supplies. The dead-code shader bounds what that buys. At Earth-fill the
shell's interior cost falls from ~370 ms toward the floor, leaving only the rim's real work. This
is the largest single win available, and it changes no pixel (see the *Addendum*).


## 3D render scale

Rendering the 3D scene at a fraction of the window and upscaling is the one lever that works
everywhere, in proportion to pixel count. It costs 12-30% less than its pixel share because some
work doesn't scale: vertex work, and glow at fixed sizes. Compatibility upscales bilinearly.
Forward+ can use FSR 1, which measured the same as bilinear at 75% (-9 to -39%) and is sharper.

Two things make it matter more than the table suggests:

- **The web canvas renders at physical pixels.** `display/window/dpi/allow_hidpi` defaults to
  true, so a laptop at 2x devicePixelRatio renders four times the pixels of a 1080p window. At that
  density 50% is not a sacrifice; it is the 1x cost.
- **The HUD is in the 3D pass.** Orbit lines, names and symbols scale with it, and the star field
  changes because its PSF is sized in render pixels.

*Figure notes (illustrated version).* At 100%, 75% and 50%, orbit lines thicken and the planet
edge softens, and 50% is clearly coarse; on the GTX this saves 22% and 35% of the Saturn frame.
Each star is drawn as a render-pixel PSF and then magnified, so lower scales give fewer, fatter
stars: detected peaks fall from 24k to 12k to 5.6k.


## The renderer, on desktop

The Windows build runs Forward+. On the iGPU that is the wrong default by a wide margin: Earth-fill
takes 4.1 s instead of ~490 ms, Saturn 263 ms instead of 54 ms, the whole-system view 64 ms instead
of 34 ms. On the GTX the two trade places by view. Forward+ wins at Earth-fill (18 vs 26 ms) and
Compatibility wins everywhere else measured.

A restart-time Renderer option is cheap to build. Point
`application/config/project_settings_override` at a `user://` file and write
`rendering/renderer/rendering_method` there; Godot reads it before the renderer starts. "Auto"
would pick Compatibility when the adapter is integrated.

What Compatibility gives up on desktop:

- Mouse-over identification of orbit lines and asteroid points (`IVFragmentIdentifier` removes
  itself there)
- FXAA and TAA
- Local shadow maps (already off for Compatibility in the Planetarium)


## The star field

2.55 million point sprites are 0.38 G vertex operations a frame, plus a few million fragments,
whatever is on screen. In the dark-sky views they are the frame: removing the field saves 46-50%
of an iGPU frame and 53-67% of a GTX frame there.

**Catalogue depth.** The magnitude cutoff earns a restart option. The bins are already separate
files, so a restart can load fewer.

| Catalogue depth | Stars | Vertex data | Build time | Dark-sky views |
|---|---:|---:|---:|---:|
| All (to V 15.4) | 2,551,210 | ~51 MB | 0.7-1.1 s | -- |
| V 11 | 942,063 | ~19 MB | 0.26-0.40 s | -25 to -31% |
| V 9.5 | 216,622 | ~4 MB | 0.07-0.10 s | -40 to -52% |

Build times are single-threaded GDScript decode on this CPU, and the web's WASM build will take
longer. In lit-body views the cut is invisible, because exposure already buries those stars. In
dark-adapted wide views V 11 thins the faint glow and V 9.5 visibly empties the sky.

**The glare wing.** `glare_scale` = 0 saves up to a quarter of a dark-sky frame. It is a bigger
visual change than the catalogue cut, because the wing is what draws the faint end. Two shader
variants that keep bright halos land in between:

- **Untapered wing:** -18%.
- **Wing gated to bright stars:** -21%.

Both still move the sky by 7-9 codes on average.

*Figure notes (illustrated version).* The whole-system view, dark-adapted: shipped, V 11 and V 9.5
across the top; glare off, untapered wing and gated wing below.


## The existing options

### MSAA

Off saves 5-13% of an iGPU frame, the low end in atmosphere views where fragment shading dwarfs
everything else, and 5-23% on the GTX. 4x costs 9-11% more than 2x on the iGPU and 3-15% on the
GTX; 8x wasn't measured. The planet rims don't need it, because the surface shaders already image
each rim pixel through the camera's PSF. What does need it is lines: orbit lines, ring edges and
spacecraft.

*Figure notes (illustrated version).* At 2x and off, only the lines change, and the dense
ring-plane orbits break into steps.

### Shadow resolution

Only Forward+ in the Planetarium draws shadow maps, and they serve only spacecraft-scale local
shadows. Their cost is not small.

- **Default 8192 on the iGPU:** about 20-25 ms a frame in views with no spacecraft anywhere near.
  2048 saves 27-39% there.
- **16384:** a 1 GiB depth atlas at 32 bits. It costs +28% to +387% on the GTX, up to 49 ms a
  frame at the Sun view, and +18% to +88% on the iGPU.

Drop 16384. Add Off, which disables the shadowed lights. Default to 4096. The atlas sizes are 16,
64, 256 and 1024 MiB.

### FXAA, TAA and Physical Light

**FXAA** is cheap line smoothing (+1 to +16%) and worth keeping.

**TAA** costs 4-39% and ghosts the orbit lines. It earns its "experimental" label, and is better
hidden.

**Physical Light** is not a performance option at all. Turning it off makes several views slower,
up to 35%, because the unmetered exposure keeps every star at full size. It belongs beside the
look settings, not under Graphics/Performance.


## Smaller levers

**Glow.** Glow saves 12-16% of an iGPU frame in light views and nothing in atmosphere views. On
the GTX it saves 1-16%, and 5-29% on Forward+. What goes is bloom around blown extended sources:
spacecraft, small moons, a bright limb. On Compatibility, turning glow off also returns the
dimmest codes that the RGB10A2 glow feed crushes.

**Cloud decks.** Clouds are cheap on the iGPU (-6 to -7%) but 22-26% of a GTX frame at Earth, 38%
on Forward+. Taking them off is a large visual loss, so this belongs in the lowest tier only.

*Figure notes (illustrated version).* At Saturn, glow off moves 8% of pixels by 5 codes or less.
The Milky Way changes nothing there, because metering on Saturn puts it below one code, yet on the
iGPU it still costs 10% of that frame. At Earth's limb, a 128x64 sphere is indistinguishable from
256x128, which is why it should simply become the default; 64x32 flecks the rim.


## Free wins: relief with no visual change

These need no option. Each removes work whose result never reaches the screen.

| Change | Measured basis | Expected relief |
|---|---|---|
| **Limb shell as a camera-facing annulus**, not a full sphere | A dead-code limb body costs the same as a hidden shell. A discarding one costs about 1/3 of the full shader. | Earth-fill ~-50 to -70% (iGPU); Titan less, since its annulus is real work |
| **Skip the sky pass** when the panorama x exposure is below one display code | Milky Way off changes zero pixels in every lit-body view | -10 to -17% (iGPU), -5 to -13% (GTX) in those views |
| **Skip star bins** the current exposure renders below one code; split the star mesh by bin | Cutting to V 11 changes zero pixels in lit-body views, yet stars cost 13-28% there | -13 to -28% in lit-body views |
| **Sphere 128x64**, or distance LOD | 128x64 measured indistinguishable | -10 to -27% |
| **Forward+: skip shadow passes** when no local caster is in range | An empty 8192 atlas costs ~20-25 ms per iGPU frame | -27 to -39% (iGPU Forward+) |
| **Sunspot LOD** by disc size | Sunspots are 36% of a Sun close-up | Near the Sun only |

**Small edits don't reliably pay on Intel.** Several of the shader-anatomy review's "exact"
micro-optimizations landed anywhere from -10% to +15% on the iGPU, depending on the view. Examples
are gating airless bodies out of the atmosphere functions, and two Newton steps in place of three
in the Compatibility colour write. Intel's code generation for shaders this large is erratic.
Structural changes are what paid every time: fewer nodes and taps, fewer fragments, fewer
vertices, less sky.

The same review found a likely bug: `atm_ring_pixel()` doesn't normalize `path` by `weight_sum`,
and its midpoint tent weights sum to 2 at one tap and 10/9 at three. That lets a close-range ring
read up to about 11% bright.


## First load on the web

Frame time is half of the web story. The other half is shader compilation, which the web pays on
every first visit because WebGL has no program-binary cache. Chrome on Windows compiles through
ANGLE and D3D11, so the app was run through Godot's own ANGLE build on the iGPU. It had not drawn
its first frame after 8.5 minutes of CPU spent compiling. Per-shader timings:

| Shader | Intel GL, first draw | +1 variant | Intel ANGLE / D3D11, first draw | +1 variant |
|---|---:|---:|---:|---:|
| `stars` | 0.4 s | 0.1 s | 0.5 s | 0.1 s |
| `body_psf` | 0.8 s | 0.2 s | 1.1 s | 0.2 s |
| `rings` | 1.3 s | 0.3 s | 4.6 s | 0.5 s |
| `surface.cube` | 9.5 s | 2.0 s | 69.1 s | 13.4 s |
| `atmosphere_limb` | 16.5 s | 3.7 s | 282.5 s | 50.2 s |
| `atmosphere_limb`, 4-node variant | 17.4 s | 4.0 s | 313.9 s | 82.3 s |

Cold compile of one shader, one process each, both caches bypassed (the harness in
`addons/tools/time_shader_compiles.py`, with an ANGLE switch added). "First draw" includes the
engine's four default variants plus the one drawn; "+1 variant" is one more specialization.

**Through ANGLE the limb shader is a first-visit hazard, not a delay.** It takes 283 s to reach
its first draw and 50 s for every further variant, about 17x its native-GL time. `surface.cube`
takes 69 s. Chrome kills its GPU process when one operation runs for roughly ten seconds, and with
it the WebGL context. So a first visit in Chrome, on Windows, on an iGPU like this one probably
cannot finish compiling these shaders. Chrome ships its own ANGLE build, whose compile flags may
differ from Godot's, so this needs confirming in the real browser on such a machine before
release. If it holds, the tier that leaves the limb shader out entirely is the only one sure to
load there.

The 4-node atmosphere variant compiles no faster than the shipped shader: its loop bounds are
already opaque uniforms, so the node count never reaches the compiler. What compiles is code
volume. A tier that pays at first load has to leave code out, not run fewer iterations of it; an
Off tier with no limb shader is the clear case. Making Atmosphere quality a restart option still
helps, because a session then compiles only the tier it uses, and the warm-up covers it.


## A possible option set

**Graphics**

- 3D render scale: 100 / 85 / 75 / 50%
- Star field: Full / Reduced (no wing) / Minimal (no wing, no Milky Way)
- Glow: on / off
- MSAA: off / 2x / 4x
- FXAA (Forward+)
- Shadow resolution (Forward+): off / 2048 / 4096 / 8192
- Frame-rate cap: 30 / 60 / uncapped

**Graphics (requires restart)**

- Renderer (desktop): Auto / Forward+ / Compatibility
- Atmosphere quality: Full / Reduced / Off
- Star catalogue: V 15 / V 11 / V 9.5
- Cloud decks: on / off

A first-run preset, chosen from the adapter, could set all of these at once. On an integrated GPU
or the web it would pick Compatibility, Reduced atmospheres, 75% scale on hi-DPI and MSAA off.


## Caveats

- **One machine.** Treat ratios and rankings as the finding, and absolute milliseconds as this
  laptop's. A newer iGPU (Iris Xe, Radeon 680M) is several times faster, but shares the same
  fragment-bound shape.
- **An Intel driver slow state.** In one of seven Intel Compatibility runs, MSAA 2x with glow's
  float buffer settled into a state about 2.3x slower in the atmosphere views. Toggling MSAA or
  glow cleared it. Repeat runs (three baselines, A/B interleaved) put the normal state at ~490 ms
  (Earth) and ~900 ms (Titan). Where a scene's baseline drifted mid-run, rows after the drift are
  excluded.
- **Estimates, not measurements.** The browser itself was not measured, so ANGLE stands in for
  Chrome. The annulus and exposure-skip relief figures are bounds from proxies rather than
  implementations. 8x MSAA and the Mobile renderer were not tested.


## Addendum: the limb ring and surface twilight

Added after the report was published, in answer to two questions: would a ring-shaped limb shell
need the four atmosphere worlds' surfaces rebaked, and would it change twilight colour on the
surfaces and on Earth's clouds?

**Neither.** Nothing is baked. The surface, cloud and band shaders compute the air in front of
themselves every frame, from the same `atm_*` values that `IVShellsModel` copies to them from the
limb row:

- the veil and twilight glow: `atm_disc_air()`;
- the sunset-reddened sunlight on the ground and on Earth's cloud deck: `atm_sun_transmittance()`;
- the colour shift from looking through the air: `atm_view_tint()`.

The limb shell contributes nothing over the disc interior. Any fragment whose ray meets the disc is
discarded (`atm_limb()` in `_atmosphere.gdshaderinc`, and the `discard` in
`atmosphere_limb.gdshader`'s fragment). Its whole job is the rays that miss the disc, plus the
outer 1% of the disc's radius (`ATM_RIM_HANDOFF`), where it and the disc shaders each draw part
of the edge haze. A ring only stops generating fragments that already contribute nothing. Two
variants that discard those interior fragments up front gave screenshots identical to the shipped
render at Earth and Titan, with zero pixels changed. The one constraint is that the ring's inner
edge must reach inside the `ATM_RIM_HANDOFF` band, plus about two pixels for the ring filter.

**What does change surface and cloud twilight is the quality tiers.**

- **Reduced:** the 4-node quadrature is also what the surface and cloud shaders use for the air in
  front of them. The change measured at most 2 display codes on Earth and up to 15 codes on 0.4% of
  Titan's pixels.
- **Off, as measured above ("All air off"):** zeroing the optical depths removes the twilight, the
  veil and the reddened sunlight entirely. Venus, Titan and Mars ship surface-reflectance maps
  that assume the air is added on top, so a no-air tier would render them wrong without
  re-levelled assets.
- **A better Off tier:** hide only the limb shell and keep the air on the disc. On the iGPU that
  saves nearly as much, 76% at Earth close-up and 94% at Titan against 80% and 95%. Surfaces and
  clouds keep their twilight. What goes is the band beyond the limb, a backlit crescent's glowing
  cusps and Titan's haze ring. The outermost 1% of the disc also loses the shell's part of the edge
  haze. This variant was measured but not screenshotted.
