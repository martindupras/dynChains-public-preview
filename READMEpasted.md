// README.md
README.md (user‑facing)



Markdown
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


Show less
2) Load the system files (in order)



SuperCollider
// Adjust the path as needed (here we assume all files are in the same folder):
~root = "/path/to/your/folder";  // e.g., thisProcess.nowExecutingPath.dirname
thisProcess.interpreter.executeFile(~root ++ "/jit_config_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_fxDefs_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_fxDefs_extras_v2.scd"); // optional, provides \chopTrem, \slapback, \ringmod
thisProcess.interpreter.executeFile(~root ++ "/jit_chain_core_v2.scd");
thisProcess.interpreter.executeFile(~root ++ "/jit_chain_utils_v2.scd");

3) Session settings



SuperCollider
(
~numCh = 6;
~jitUseRealInput    = true;   // Use SoundIn(0 .. 5)
~jitUseSplayDownmix = true;   // Use Splay for stereo destination
~sourceAmp   = 0.7;
~defaultAmp  = 0.8;
~jitFadeTime = 0.25;
)

4) Build a chain and play



SuperCollider
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

Try these presets (clearly audible)



SuperCollider
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


Show more lines
Live‑tweak while playing



SuperCollider
// Chopper extremes
~jitSetFx.(\ch1, (rate:12, duty:0.15, smooth:0.001));
~jitSetFx.(\ch1, (rate:6,  duty:0.5,  smooth:0.004));

// Ringmod: wobble vs metallic
~jitSetFx.(\rm1, (freq:80));
~jitSetFx.(\rm1, (freq:2000));

// Slapback: more repeats, darker
~jitSetFx.(\sl1, (decay:2.8, mix:1.0, damp:2500, wobbleDepth:0.004));

Editing the chain (insert / move / remove)



SuperCollider
~jitInsertStage.(1, [\flanger, (id:\fl1, rate:0.2, depth:0.004, mix:0.5)]);
~jitMoveStage.(\fl1, 0);     // move flanger to first stage
~jitRemoveStage.(\ch1);      // remove by id

Stopping / cleanup



SuperCollider
~jitFree.();  // stops and clears both proxies and resets internal state

Troubleshooting
No sound?
Make sure ~jitUseRealInput = true and your source has signal on input buses 0..5.
Confirm device names/spellings and channel counts.
Range operator .. error? Use spaces: 0 .. 5, or use Array.series(6, 0, 1).
Clipping? Reduce src_amp / dest_amp:



SuperCollider
~jitSetSource.( (src_amp: 0.6) );
~jitSetDest.(   (dest_amp: 0.8) );

Prefer weighted downmix instead of Splay? Set ~jitUseSplayDownmix = false before building.
Evaluate in the editor, not the one‑line Command Line (to avoid parse quirks).
Files in this repo
jit_session_hexSplay_demo_v2.scd – one‑shot session for quick use (recommended).
jit_config_v2.scd – user‑level params and registry.
jit_fxDefs_v2.scd – base FX builders (\tremolo, \flanger, \delay, etc.).
jit_fxDefs_extras_v2.scd – obvious FX (\chopTrem, \slapback, \ringmod). Optional.
jit_chain_core_v2.scd – build/play the chain, source/destination wiring.
jit_chain_utils_v2.scd – editing ops, parameter setters, and status tools.
See README_source.md for implementation details.


---

## `README_source.md` (developer‑facing)

```markdown
# Dynamic Signal Chain – Source & Architecture
JITLib / `Ndef`‑based, list‑driven FX chains for multichannel input.

---

## Load order
1. `jit_config_v2.scd`
2. `jit_fxDefs_v2.scd`
3. `jit_fxDefs_extras_v2.scd` (optional)
4. `jit_chain_core_v2.scd`
5. `jit_chain_utils_v2.scd`

The session script `jit_session_hexSplay_demo_v2.scd` loads these in order and either loads the extras file or inlines the extras builders.

---

## Signal flow (high level)
SoundIn (0 .. ~numCh-1) or WhiteNoise ! ~numCh → Ndef(\chain) // source is slot 0 + filter slot 1 (first FX) + filter slot 2 (second FX) ... → Ndef(\out) // destination; stereo downmix (Splay or weighted), or passthrough → hardware outs


- **Source**: `SoundIn.ar(0 .. (~numCh - 1))` when `~jitUseRealInput == true`; otherwise `WhiteNoise.ar(0.3) ! ~numCh`. Multiplied by `src_amp` (NamedControl).
- **Destination**:
  - If last spec symbol is `\destinationStereo` **or** server has ≤ 2 output channels → produce **stereo**:
    - If `~jitUseSplayDownmix == true` → `Splay.ar(in)` *(equal‑energy spread)*.
    - Else → **weighted mixer** (channels 0/1 hard L/R, others blended).
  - Else → pass through the multichannel signal.
  - Multiplied by `dest_amp` (NamedControl).

---

## Spec format (list‑driven)
A chain is defined by an **Array**:

```supercollider
[
  \guitar,
  [\effectSymbol, (id:\uniqueId, param1: value1, ...)],  // zero or more stages
  ...,
  \destination            // or \destinationStereo
]
\guitar and the destination symbol are required.
Stages can be:
\symbol (no params)
[\symbol, (id:\myId, k:v, ...)]
[\symbol, \k, v, \k2, v2, ...] (flat key/value pairs)
Validation happens in ~jitBuild: start symbol, end symbol, and that every \symbol has a builder in ~fxBuilders.

Stage indexing, IDs, and control prefixes
User stage indices are 0..n‑1 (first stage after \guitar is 0).
Internally, filters are installed via Ndef(\chain).filter(slotIndex), where slot 1 corresponds to user stage 0 (slot 0 is the source).
Each stage gets a control prefix:
~jitStagePrefixFor.(slot, id)
→ string "fx{slot}" if no ID, or id.asString if an \id was provided.
Control names are constructed as "{prefix}_{param}".
Runtime registries:
~jitStageIndexNodes (Array of prefixes by stage index).
~jitStageIdInfo (IdentityDictionary mapping id → (slot:, prefix:)).
~jitCurrentSpec (copy of the last spec built).
Setters in jit_chain_utils_v2.scd convert user params into the correct prefixed control names:

~jitSetFx.(which, params) — which can be stage index (Integer) or stage \id.
~jitSetSource.(params) — sets Ndef(\chain) controls (e.g., src_amp).
~jitSetDest.(params) — sets Ndef(\out) controls (e.g., dest_amp).
Builders contract (~fxBuilders)
~fxBuilders is an IdentityDictionary mapping \symbol → builder function.
A builder has the form:



SuperCollider
~fxBuilders[\symbol] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);  // ensures `a.at(\key) ? default` is safe
    { |in|
        var ...controls..., ...locals...;
        // Controls: NamedControl.kr((prefix ++ "_param").asSymbol, default)
        // Processing: return a signal with the same channel count as `in`
        XFade2.ar(in, processed, (mixCtl * 2) - 1)  // common pattern
    }
};

Conventions followed here:
Caret‑free language code (no ^).
var declarations at the top of each UGen function ({ |in| ... }).
Per‑channel safe (UGens applied to the incoming multichannel in).
Fixed control name scheme: prefix_param.
Base builders (in jit_fxDefs_v2.scd)
\tremolo, \flanger, \delay, \downmix6to2 (utility, not used by main chain).
Extras (in jit_fxDefs_extras_v2.scd or inlined by the session)
\chopTrem — hard chopping tremolo using LFPulse with optional smoothing.
Controls: rate, duty, smooth, mix.
\slapback — spring‑like slapback echo using CombC with tone shaping and wow.
Controls: time, decay, mix, damp (LPF), hp (HPF), wobbleRate, wobbleDepth.
Implementation detail: modTime = SinOsc.kr(wobRate).madd(wobDepth, time) (avoids the unary - parser issue).
\ringmod — classic AM ring modulation.
Controls: freq, mix. Carrier is duplicated to match channel count.
Chain build (~jitBuild)
Validates the spec (start/end symbols, known builders).
Clears and (re)initializes Ndef(\chain) with the source UGen.
Adds filters with Ndef(\chain).filter(i+1, builder.(prefix, args)).
Decides output mode:
Stereo via Splay or weighted mix if \destinationStereo or server outs ≤ 2.
Multichannel passthrough otherwise.
Sets ~jitCurrentSpec, updates registries, and prints a short confirmation.
Note: In the v2 code you shared, the “abort on invalid spec” line didn’t actually short‑circuit the build:




SuperCollider
ok.if({}, { nil });

If you want strict abort semantics, wrap the build body in ok.if({ ... }, { nil }).

Utilities (jit_chain_utils_v2.scd)
Spec edit ops:
~jitInsertStage.(position, entry)
~jitRemoveStage.(which) // index or \id
~jitMoveStage.(which, newPosition) // index or \id
Setters: ~jitSetFx, ~jitSetSource, ~jitSetDest
Introspection:
~jitStatus.() — prints spec, id map, node list, channel counts, and current toggles.
~jitDebugDump.() — dumps registry contents.
Proxies and fade time
NodeProxy.defaultFadeTime is set from ~jitFadeTime if supported.
Per‑proxy fadeTime is set for Ndef(\chain) and Ndef(\out) before assigning sources/filters.
Chains fade smoothly when rebuilt or when setters adjust controls.
Coding conventions (project‑wide)
Interpreter (tilde) vars in lowercase (e.g., ~numCh, not ~NumCh).
var declarations before any statements inside UGen functions.
Caret‑free in language‑side functions to keep blocks expression‑driven and safe to inline.
Control naming: prefix_param via NamedControl.kr, where prefix derives from stage index or the stage \id.
Known SC quirks & fixes
Range operator: write 0 .. 5 (with spaces) or use Array.series(6, 0, 1).
Unary minus inside argument lists (e.g., .range(-x, x)) can confuse the parser in the Command Line; prefer .madd(scale, offset) or evaluate in the editor.
Evaluate in the editor, not the one‑line Command Line. The latter often produces Command line parse failed for multi‑line code.
Extending the system
Add a new effect
Use this template (drop into jit_fxDefs_v2.scd or an extras file):




SuperCollider
~fxBuilders[\myEffect] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);
    { |in|
        var rateCtl, depthCtl, mixCtl, processed;
        rateCtl = NamedControl.kr((prefix ++ "_rate").asSymbol, (a.at(\rate) ? 2.0));
        depthCtl = NamedControl.kr((prefix ++ "_depth").asSymbol, (a.at(\depth) ? 0.5));
        mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol, (a.at(\mix) ? 0.8)).clip(0.0, 1.0);

        // ... do something audible with `in` ...
        processed = in * (1 + (SinOsc.kr(rateCtl) * depthCtl));

        XFade2.ar(in, processed, (mixCtl * 2) - 1)
    }
};


Show more lines
Then add to a spec:




SuperCollider
[\myEffect, (id:\me1, rate:4, depth:0.7, mix:1.0)]

Add a safety limiter (optional)
Append this builder near the end of your chain to prevent clipping while auditioning:




SuperCollider
~fxBuilders[\safetyLimiter] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);
    { |in|
        var threshCtl, releaseCtl;
        threshCtl  = NamedControl.kr((prefix ++ "_thresh").asSymbol, (a.at(\thresh) ? 0.98)).clip(0.1, 1.0);
        releaseCtl = NamedControl.kr((prefix ++ "_release").asSymbol, (a.at(\release) ? 0.1)).clip(0.01, 1.0);
        Limiter.ar(in, threshCtl, releaseCtl)
    }
};

Use it as the last stage before \destinationStereo.

File overview
jit_config_v2.scd
Session parameters & toggles:
~numCh, ~outOffset, ~sourceAmp (src_amp), ~defaultAmp (dest_amp), ~jitFadeTime,
~jitUseRealInput, ~jitUseSplayDownmix;
registries and ~jitClearState helper.

jit_fxDefs_v2.scd
Base FX: \tremolo, \flanger, \delay, \downmix6to2 utility.
All controls via NamedControl with prefixed names.

jit_fxDefs_extras_v2.scd (optional)
Obvious demo FX: \chopTrem, \slapback (uses CombC + tone + wow), \ringmod.
Fix uses .madd for SinOsc time modulation.

jit_chain_core_v2.scd
~jitBuild (validates, constructs source + filters, sets destination),
~jitPlay, ~jitFree, CmdPeriod hook, downmix logic (Splay/weighted).

jit_chain_utils_v2.scd
Spec edit ops (insert/remove/move), setters (~jitSetFx, ~jitSetSource, ~jitSetDest),
introspection (~jitStatus, ~jitDebugDump), and helpers (~toKeyValueArray, etc.).

jit_session_hexSplay_demo_v2.scd
All‑in‑one runnable demo: boots devices, loads files, defines extras if needed,
builds a loud, obvious chain, and starts playback.

Maintenance notes
If you change device names/channel counts, do it at the top of the session file or the boot block.
If you add FX, remember:
Give stages an \id for easy live control via ~jitSetFx.
Keep control names consistent (prefix_param).
For stricter validation, wrap ~jitBuild’s main body in an ok.if({ ... }, { nil }) to fully abort on invalid specs.

If you want, I can also add a **minimal LICENSE** and a **preset switcher** (`~jitLoadPreset.(\name)`) for quick comparisons, and wire the presets shown in the user README into that. Shall I include those?






