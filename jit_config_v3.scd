// jit_config_v3.scd
// MD 20250902 — Session-wide defaults and lightweight helpers only

(
~jitConfigLoaded = (~jitConfigLoaded ? false);

~jitConfigLoaded.if({
    // Already loaded in this session; skip reapplying values
    ("[jit][CFG v3] already loaded; skipping — " ++ thisProcess.nowExecutingPath).postln;
},{
    ~jitConfigLoaded = true;
    ("[jit][CFG v3 self-contained] loaded from: " ++ thisProcess.nowExecutingPath).postln;

    /* ... (unchanged header comments) ... */

    // ---- Core session parameters ----
    ~numCh         = (~numCh         ? 6).asInteger.clip(1, 64);
    ~outOffset     = (~outOffset     ? 0).asInteger.max(0);
    ~sourceAmp     = (~sourceAmp     ? 0.6).asFloat.clip(0, 2);
    ~defaultAmp    = (~defaultAmp    ? 0.8).asFloat.clip(0, 2);
    ~jitFadeTime   = (~jitFadeTime   ? 0.25).asFloat.max(0.0);

    // Session toggles
    ~jitUseRealInput     = (~jitUseRealInput     ? false);
    ~jitUseSplayDownmix  = (~jitUseSplayDownmix  ? false);

    // Apply a global default for JITLib proxies (optional; per-proxy fadeTime is also set in jit_chain)
    if(NodeProxy.respondsTo(\defaultFadeTime_)) {
        NodeProxy.defaultFadeTime = ~jitFadeTime;
    };

    // ---- Runtime registry (used by jit_chain; safe to initialize here) ----
    ~jitStageIndexNodes = (~jitStageIndexNodes ? []);
    ~jitStageIdInfo     = (~jitStageIdInfo     ? IdentityDictionary.new);
    ~jitCurrentSpec     = (~jitCurrentSpec     ? nil);

    // ---- Quick clear for registries only (no server/proxy side-effects) ----
    ~jitClearState = {
        ~jitStageIndexNodes = [];
        ~jitStageIdInfo.clear;
        ~jitCurrentSpec = nil;
    };
});
)
