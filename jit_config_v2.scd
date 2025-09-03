// jit_config_v2.scd
// MD 20250829 — Session-wide defaults and lightweight helpers only

(
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
)
