# Migrating the JITLib Script System to a Class‑Based Architecture

This document discusses the advantages and disadvantages of refactoring the current **SuperCollider/JITLib** script setup (tilde vars + runtime functions in `.scd`) into **class code** (`.sc` files), with specific attention to: **simplicity, consistency, debugging & maintenance, and integration** with your **CommandTree** system.

---

## TL;DR (When to Choose What)

- **Stay script‑based** if you’re actively exploring DSP ideas and want instant iteration (Shift+Return) without recompiling the class library.
- **Move to classes** if you’re ready to stabilize a public API for collaborators, avoid global state, support **multiple independent chains**, and integrate cleanly with **CommandTree**.
- **Best of both worlds:** a **hybrid**: put **orchestration & API** into classes, but keep **UGen builder functions** hot‑swappable in `.scd` files.

---

## Side‑by‑Side: Scripts vs Classes

| Concern | Script (current) | Classes (proposed) |
|---|---|---|
| **Simplicity** | One file; evaluate and go. Minimal boilerplate. | Some ceremony (class headers, placing files in Extensions or project path, Recompile Class Library). |
| **Consistency / Namespacing** | Globals (e.g., `~fxBuilders`, `~jitBuild`) can collide. | Namespaced methods & ivars; fewer global side‑effects; clearer mental model. |
| **Debugging / Maintenance** | Easy to poke & print, but state can drift; weak testability. | Encapsulation + stable methods; easier unit tests and systematic logging. |
| **Hot‑reload** | Instant (Shift+Return). | Requires **Recompile Class Library** after code changes. |
| **Multiple chains** | Hard: fixed `Ndef(\chain)`, `Ndef(\out)` names collide. | Easy: instance‑scoped names (e.g., `\chain_md1`, `\out_md1`). |
| **Integration (CommandTree)** | Commands call tilde functions; fragile naming. | Stable, documented methods; 1:1 mapping from commands to methods. |
| **Distribution** | Users must evaluate scripts in order. | Users drop classes into `Extensions/` or project path; dependency order handled by the compiler. |
| **Testing / CI** | Ad‑hoc. | sclang `UnitTest` fixtures can exercise class methods deterministically. |

---

## Concrete Advantages of Classes in This Project

1. **Stable Public API**: e.g., `JITSession.boot`, `JITChain.build/spec`, `JITChain.play/free`, `JITChain.setFx/setSource/setDest`, `JITChain.insert/move/remove`, and a `JITFxRegistry`.
2. **Instance Isolation**: multiple chains with unique `Ndef` keys per instance; safe A/B comparisons, multi‑player, etc.
3. **Encapsulated I/O & Server Lifecycle**: one place for device checks, `ServerOptions`, reboot, and `waitForBoot` logic.
4. **Single Source of Truth for Config**: validated ranges for `numCh`, `useRealInput`, `useSplayDownmix`, `sourceAmp`, `defaultAmp`, `fadeTime`.
5. **Centralized Logging & Verbosity**: consistent tags like `[jit][chain md1] …` and a shared verbosity level.
6. **Cleaner CommandTree Integration**: CommandTree nodes call stable methods; responses and errors are uniform.

---

## Real Costs / Drawbacks

1. **Recompile Friction**: editing class files requires **Recompile Class Library**; slows rapid DSP iteration.
2. **More Boilerplate**: constructors, ivars, accessors, class docs; not huge, but non‑zero.
3. **Less Immediate FX Iteration** (if you move builders into classes): every tweak needs a recompile. (Mitigate via hybrid.)
4. **Onboarding**: collaborators must know where to place `.sc` files (project path or `Extensions/`) and how to recompile.

---

## Design Sketch (Mapping Your v2 Code to Classes)

> These are conceptual roles, not drop‑in code. They mirror your existing `v2` functions.

### `JITFxRegistry` (class)
- **Role**: registry: `\symbol -> builderFunc(prefix, args) -> { |in| ... }`.
- **Why**: keep FX builders as *functions* so you can hot‑swap them without recompiling.
- **API**: `add(\sym, func)`, `has(\sym)`, `build(\sym, prefix, argsDict)`, `list()`.

### `JITConfig` (class)
- **Role**: defaults + validation for session fields: `numCh`, `outOffset`, `sourceAmp`, `defaultAmp`, `fadeTime`, `useRealInput`, `useSplayDownmix`.
- **API**: `validate()`, `applyNodeProxyDefaults()`, `asDict()`; optionally class‑side defaults.

### `JITChain` (instance class)
- **Role**: owns a chain and its `Ndef` names; builds, plays, frees; edits stages; sets params.
- **State**: `server`, `chainKey`, `outKey`, `config`, `spec`, `stageIndexNodes`, `stageIdInfo`.
- **API**: `build(spec)`, `play(offset=0)`, `stop()`, `free()`, `insertStage()`, `removeStage()`, `moveStage()`, `setFx()`, `setSource()`, `setDest()`, `status()`.

### `JITSession` (optional)
- **Role**: boot/reboot + multi‑chain registry.
- **API**: `boot(inDev, outDev, numIn, numOut, sampleRate?)`, `newChain(id?)`, `chain(id)`, `listChains()`.

---

## Hybrid Strategy (Recommended Now)

- Keep **FX builders** in `.scd` files (e.g., your current `jit_fxDefs_v2.scd`, `jit_fxDefs_extras_v2.scd`).
- After class load, evaluate those scripts and **register** with the class registry:

```supercollider
// After recompile / startup
thisProcess.interpreter.executeFile("jit_fxDefs_v2.scd");
thisProcess.interpreter.executeFile("jit_fxDefs_extras_v2.scd");
JITFxRegistry.addAll(~fxBuilders); // convenience method to bulk‑register
```

- Implement the **public API** in classes; keep your session scripts thin. You still get instant FX iteration.
- Provide a **back‑compat shim** so existing tilde calls route to a default `JITChain` instance while CommandTree migrates to the class API.

---

## Debugging & Maintenance Improvements with Classes

- **Centralized logging/verbosity**: toggle once; all methods respect it.
- **State inspection**: `JITChain.status` returns a struct (spec, id map, channels, options) instead of scattered `postln`s.
- **Safer rebuild**: fully abort invalid specs (wrap build body in `ok.if({ ... }, { ^nil })` in class code) so proxies aren’t partially mutated.
- **Tests**: write small fixtures to build a chain, set params, and assert prefix resolutions and slot mappings.

---

## CommandTree Integration

- Commands map 1:1 to methods:
  - `build` → `chain.build(spec)`
  - `play`  → `chain.play(offset)`
  - `stop`  → `chain.stop()`
  - `free`  → `chain.free()`
  - `insert/remove/move` → respective methods
  - `setFx/setSource/setDest` → setters
- Parameter marshalling & prefix rewriting remain internal to the chain.
- Optional callbacks: `onBuilt`, `onError` for UI feedback.

---

## Migration Plan (2 Afternoons, Incremental)

**Phase 0 (30–60 min):** Create empty class shells: `JITFxRegistry`, `JITConfig`, `JITChain`.

**Phase 1 (1–2 hrs):** Port orchestration from `~jitBuild/~jitPlay/~jitFree` into `JITChain` (instance‑scoped Ndef names). Keep using `~fxBuilders` under the hood.

**Phase 2 (1–2 hrs):** Add `JITSession.boot` (device options + reboot). Implement edit ops and setters on `JITChain`. Add a **compat shim** routing tilde calls to a default chain.

**Phase 3 (optional):** Port verbosity to `JITConfig`; add a small `JITPresets` helper or methods for demo chains.

---

## Next Steps I Can Provide

- **Starter class trio** (`JITFxRegistry.sc`, `JITConfig.sc`, `JITChain.sc`) that directly wraps your v2 logic.
- **Compat shim** so existing `.scd` sessions continue to work.
- **Updated session script** demonstrating loading FX scripts, registering with the registry, and building via `JITChain`.

**Question for you:** preferred class naming (`JITChain` vs `MDJITChain`) and whether you want multi‑chain support on day 1 (recommended).
