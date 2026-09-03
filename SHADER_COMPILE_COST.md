# Shader Compile Cost

How long this project's shaders take the GPU driver to compile and link, which renderer that
hurts on, and what an edit to a given file costs. It is here because the answer is
counter-intuitive in both directions: the cost does not track how long a shader is, and the
file you would guess is expensive is not.

Measured 2026-09-02 against Godot 4.7.2 with `ivoyager_core` at `f478953`. Numbers are one
machine's -- treat the *ordering* and the *ratios* as the finding, not the absolute seconds.


## The symptom

Under the **Compatibility** renderer, a run made shortly after any shader edit starts slowly and
then drops a multi-second frame the first time the camera reaches certain bodies. It clears
after one run and stays cleared until the next shader edit.

That is not a bug in anything. GLES3 compiles a shader program **at first draw**, synchronously,
on the main thread. What the opening view draws compiles during startup; everything else
compiles the first time it is drawn, which is when you fly to a body whose shader nothing has
drawn yet. Forward+ shows the same effect an order of magnitude smaller.


## What it costs

From-scratch compile and link of one specialization, timed as the duration of the frame in which
a fresh material first draws:

| shader | Compatibility | Forward+ | source |
|---|---|---|---|
| `atmosphere_limb` | **26.5 s** | 1.4 s | 8.3 KB |
| `cloud_shell.cube` | 12.6 s | 1.3 s | 16.7 KB |
| `surface.cube` | 12.5 s | 2.6 s | 19.3 KB |
| `cloud_shell` | 12.5 s | 1.4 s | 15.5 KB |
| `band_pattern` | 12.4 s | 2.3 s | 22.6 KB |
| `surface` | 11.3 s | 2.4 s | 17.8 KB |
| `sun_surface` | 10.6 s | 0.20 s | 8.2 KB |
| `body_psf` | 1.08 s | 0.19 s | 25.1 KB |
| `rings` | 0.55 s | 0.55 s | 11.3 KB |
| `stars` | 0.24 s | 0.12 s | 11.8 KB |
| `path` | 0.21 s | 0.13 s | 1.8 KB |
| `farwarp_vertex` | 0.20 s | 0.12 s | 1.8 KB |
| `starmap_background` | 0.02 s | 0.02 s | 2.7 KB |
| **total** | **100.6 s** | **12.7 s** | |

`sun_surface.cube`, `instance_id`, `path_id`, `orbiting_positions_id` and
`orbiting_positions_lp_id` were not measured. The three id shaders are trivial;
`sun_surface.cube` should resemble `sun_surface`.

**Compatibility costs 8x Forward+ overall and up to 53x on one shader** (`sun_surface`, 10.6 s
against 0.20 s). Repeatability is good: `surface` came out at 11.40 s and 11.30 s on two
separate runs.


## What drives it

**Not source length, and not lit versus `unshaded`.** `body_psf.gdshader` is the longest source
in the project and among the cheapest to compile. `sun_surface` is `unshaded` and costs 10.6 s;
`rings` is lit and costs 0.55 s.

**It is the heavy procedural includes.** The expensive set is exactly the six shaders that pull
in `_atmosphere.gdshaderinc`, plus the two that pull in `_sun_photosphere.gdshaderinc`. Nothing
outside those two families costs more than about a second.

`_photometry.gdshaderinc` is *not* a driver of cost, which is worth stating because its two
16-cell constant-bound loops (`limb_mean_incidence`, `limb_sky_side_incidence`) look like the
obvious suspect: a GL compiler fully unrolls them and each cell inlines an `asin`, an `atan` and
four `sin` calls. The two cheapest lit shaders in the project, `rings` and `body_psf`, both
include it.


## What an edit costs

Editing a file invalidates every shader that `#include`s it, so its cost is the sum over that
set. Complete sums (every constituent measured):

| edited file | shaders hit | Compatibility |
|---|---|---|
| `_atmosphere.gdshaderinc` | 6 | **88 s** |
| `_sun_occlusion.gdshaderinc` | 7 | **88 s** |
| `_photometry.gdshaderinc` | 7 | **63 s** |
| `body_psf.gdshader` | 1 | **1.1 s** |

`_display`, `_farwarp` and `_point_spread_function` reach nearly every shader in the project, so
editing one of those costs roughly the whole 100 s; `_detail.gdshaderinc` reaches eight and costs
at least 72 s.

This is the practical rule of thumb while working: a change confined to `body_psf.gdshader` is
free, a change to `_photometry.gdshaderinc` costs about a minute of compiling on the next
Compatibility run, and a change to `_atmosphere.gdshaderinc` costs about a minute and a half --
paid partly at startup and partly as first-visit frame hangs.


## Where the caches are

Two of them, stacked, and you have to know about both to reason about a slow run.

**Godot's** is per-project and keyed on the GLSL that Godot *generates*. Its location depends on
how you launch:

- an editor run (F5) writes `<project>/.godot/shader_cache`
- a standalone run (`--path`, or an exported build) writes
  `%APPDATA%/Godot/app_userdata/I, Voyager - Planetarium/shader_cache`

These do not share entries. Clearing the wrong one measures nothing.

**The GL driver keeps its own program cache underneath Godot's.** Deleting Godot's cache while
the shader source is unchanged still returns in well under a second, because the driver answers
from its own. Only a genuinely novel source misses both -- which is exactly what a real edit is.


## The web export

The web export is GLES3, and a first-time visitor arrives with neither cache. The 100 s total is
the worst case (every shader, nothing cached, one variant each; a real scene may compile more
than one variant per shader), but even a fraction of it is a bad first load, and Godot's shader
cache cannot help someone who has never run it.

If that needs cutting, the lever is `_atmosphere.gdshaderinc`: it holds the single most expensive
shader and the widest expensive reach. Measure an actual web load first -- browser and driver
caching may already absorb much of it.


## How to measure it again

Put the shader on a small quad in front of the camera, append a `uniform float bust_<random> =
0.0;` to its source so neither cache can answer, assign the material, and time the frame it first
draws in. Four traps, each of which cost a run:

- **A comment does not invalidate anything.** Godot hashes the GLSL it generates and the parser
  drops comments, so appending `// bust` changes the file on disk and nothing downstream. Append a
  uniform.
- **`RenderingServer.force_draw()` cannot be used** from inside an `ivoyager_assistant` method:
  the server dispatches in `_process`, and re-entering the renderer there deadlocks the
  application. Time across frames instead -- a helper `Node` with `_process` and
  `Time.get_ticks_usec()` deltas, assigning the material on frame N and reading the delta on
  N+1. A deadlocked instance keeps holding port 29071, so every later run talks to the corpse;
  check for stray processes before believing a "no response".
- **A runtime `Shader` has no resource path**, so the relative `#include "_x.gdshaderinc"` the
  shipped files use will not resolve. Rewrite them to
  `res://addons/ivoyager_core/shaders/_x.gdshaderinc`.
- **Discard the first shader measured.** It also pays the probe quad's own first draw.

Vsync makes the baseline frame 16.9 ms, which is far enough below these costs to read them
straight off. Godot's `--print-fps` is enough to *find* a stall in a normal session -- it prints
one line per second, and a hang shows up as a single low-FPS second -- but not to attribute one.
