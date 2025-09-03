# Dynamic Signal Chain (JITLib / SuperCollider)
**6‑channel input → dynamic FX chain → stereo out via `Splay`**  
Fast, flexible, and live‑tweakable chains built on `Ndef` proxies.

---

## What this is
A small system that lets you:
- Take **6 channels** from a hexaphonic source (e.g. BlackHole 16ch bus 0–5).
- Build a **list‑driven** chain of effects using `Ndef` / JITLib.
- **Live‑tweak** FX parameters with named controls.
- **Downmix** to stereo using `Splay` (or a weighted mix) for easy monitoring.

---

## Requirements
- **SuperCollider 3.x**
- macOS with CoreAudio devices:
  - Input: **“BlackHole 16ch”**
  - Output: **“MacBook Pro Speakers”** (or any stereo device)
- Evaluate code in a **document** with **Shift+Return** (avoid the one‑line Command Line).

---

## Quickstart (best way)
Use the session script that boots, loads, defines obvious demo FX, builds a chain, and plays:

**File:** `jit_session_hexSplay_demo_v2.scd`  
Place it in the same folder as the core `v2` files. Then open it in SuperCollider and evaluate **the whole file**.

What it does:
1. Sets the audio devices and reboots the server.
2. Loads the core files (config, base FX, chain core, utils).
3. Loads extras (either from `jit_fxDefs_extras_v2.scd` if present, or inline fallback).
4. Builds a **clearly audible** chain:
   - `\chopTrem` → `\ringmod` → `\slapback` → `\destinationStereo`
5. Starts playback and opens the meter.

---

## Manual usage (step‑by‑step)

### 1) Boot with devices
```supercollider
(
s.options.inDevice  = "BlackHole 16ch";
s.options.outDevice = "MacBook Pro Speakers";
s.options.numInputBusChannels  = 6;
s.options.numOutputBusChannels = 2;
s.reboot;
)
```

### 2) Load the system files (in order)
```supercollider
// Adjust the path as needed (here we assume all files are in the same folder):
~root = "/path/to/your/folder";  // e.g., thisProcess.nowExecutingPath.dirname
thisProcess.interpreter.executeFile(~root ++ "/jit_config_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_fxDefs_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_fxDefs_extras_v2.scd"); // optional, provides \chopTrem, \slapback, \ringmod
thisProcess.interpreter.executeFile(~root ++ "/jit_chain_core_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_chain_utils_v2.scd");
```

### 3) Session settings
```supercollider
(
~numCh = 6;
~jitUseRealInput    = true;   // Use SoundIn(0 .. 5)
~jitUseSplayDownmix = true;   // Use Splay for stereo destination
~sourceAmp   = 0.7;
~defaultAmp  = 0.8;
~jitFadeTime = 0.25;
)
```

### 4) Build a chain and play
```supercollider
(
var spec = [
  \guitar,
  [\chopTrem, (id:\ch1, rate:8, duty:0.25, smooth:0.003, mix:1.0)],
  [\ringmod,  (id:\rm1, freq:500, mix:0.85)],
  [\slapback, (id:\sl1, time:0.12, decay:1.8, mix:0.9,
               damp:3200, hp:120, wobbleRate:0.7, wobbleDepth:0.002)],
  \destinationStereo
];
~jitBuild.(spec);
~jitPlay.();
s.meter;
)
```

---

## Try these presets (clearly audible)

```supercollider
// 1) Hard stutter + springy echo
~jitBuild.([
  \guitar,
  [\chopTrem, (id:\ch1, rate:10, duty:0.20, smooth:0.002, mix:1.0)],
  [\slapback, (id:\sl1, time:0.11, decay:2.2, mix:1.0, damp:3000, hp:120, wobbleRate:0.7, wobbleDepth:0.003)],
  \destinationStereo
]); ~jitPlay.();

// 2) Metallic AM + dubby trails
~jitBuild.([
  \guitar,
  [\ringmod,  (id:\rm1, freq:1100, mix:1.0)],
  [\delay,    (id:\d1,  time:0.32, feedback:0.7, mix:0.8)],
  \destinationStereo
]); ~jitPlay.();

// 3) Slow swirl (wide flanger) + slapback
~jitBuild.([
  \guitar,
  [\flanger,  (id:\fl1, rate:0.08, depth:0.006, delay:0.004, mix:0.9)],
  [\slapback, (id:\sl1, time:0.13, decay:1.6, mix:0.8, damp:4000, hp:100, wobbleRate:0.3, wobbleDepth:0.001)],
  \destinationStereo
]); ~jitPlay.();
```

---

## Live‑tweak while playing
```supercollider
// Chopper extremes
~jitSetFx.(\ch1, (rate:12, duty:0.15, smooth:0.001));
~jitSetFx.(\ch1, (rate:6,  duty:0.5,  smooth:0.004));

// Ringmod: wobble vs metallic
~jitSetFx.(\rm1, (freq:80));
~jitSetFx.(\rm1, (freq:2000));

// Slapback: more repeats, darker
~jitSetFx.(\sl1, (decay:2.8, mix:1.0, damp:2500, wobbleDepth:0.004));
```

---

## Editing the chain (insert / move / remove)
```supercollider
~jitInsertStage.(1, [\flanger, (id:\fl1, rate:0.2, depth:0.004, mix:0.5)]);
~jitMoveStage.(\fl1, 0);     // move flanger to first stage
~jitRemoveStage.(\ch1);      // remove by id
```

---

## Stopping / cleanup
```supercollider
~jitFree.();  // stops and clears both proxies and resets internal state
```

---

## Troubleshooting
- **No sound?**  
  - Make sure `~jitUseRealInput = true` and your source has signal on **input buses 0..5**.  
  - Confirm device names/spellings and channel counts.
- **Range operator `..` error?** Use spaces: `0 .. 5`, or use `Array.series(6, 0, 1)`.
- **Clipping?** Reduce `src_amp` / `dest_amp`:
  ```supercollider
  ~jitSetSource.( (src_amp: 0.6) );
  ~jitSetDest.(   (dest_amp: 0.8) );
  ```
- **Prefer weighted downmix instead of Splay?** Set `~jitUseSplayDownmix = false` before building.
- **Evaluate in the editor**, not the one‑line Command Line (to avoid parse quirks).

---

## Files in this repo
- `jit_session_hexSplay_demo_v2.scd` – one‑shot session for quick use (recommended).
- `jit_config_v2.scd` – user‑level params and registry.
- `jit_fxDefs_v2.scd` – base FX builders (`\tremolo`, `\flanger`, `\delay`, etc.).
- `jit_fxDefs_extras_v2.scd` – obvious FX (`\chopTrem`, `\slapback`, `\ringmod`). Optional.
- `jit_chain_core_v2.scd` – build/play the chain, source/destination wiring.
- `jit_chain_utils_v2.scd` – editing ops, parameter setters, and status tools.

See **`README_source.md`** for implementation details.
