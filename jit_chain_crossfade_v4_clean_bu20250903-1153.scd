// jit_chain_crossfade_v4_clean.scd
// Self-contained v4 crossfade engine with adapter mapping.
// Requirements satisfied:
//   - No server.sync, no try/protect, caret-free, tilde-globals only.
//   - Debounced inactive-side builds, no clear+put churn.
//   - Deterministic GUI state (Next row) on preview & switch.
//   - Token-guarded loser stop after (fade + tail).

(
// -------------------------------
// Global CF state (initialized once)
// -------------------------------
~jitCFFadeTime      = (~jitCFFadeTime      ? 0.08);  // default fade seconds
~jitCFTailTime      = (~jitCFTailTime      ? 0.25);  // default tail seconds
~jitCFActiveSide    = (~jitCFActiveSide    ? \A);    // current active side (\A or \B)
~jitCFDebounceSec   = (~jitCFDebounceSec   ? 0.08);  // debounce for side rebuilds

~jitCFBuildLatest       = (~jitCFBuildLatest       ? IdentityDictionary.new); // \outA/\outB -> spec
~jitCFDebounceRunning   = (~jitCFDebounceRunning   ? IdentityDictionary.new); // \outA/\outB -> bool
~jitCFBuildPending      = (~jitCFBuildPending      ? IdentityDictionary.new); // \outA/\outB -> bool
~jitCFGates             = (~jitCFGates             ? IdentityDictionary.new); // \outA/\outB -> 0/1
~jitCFStopToken         = (~jitCFStopToken         ? IdentityDictionary.new); // \outA/\outB -> int
~jitCFStopTokenCounter  = (~jitCFStopTokenCounter  ? 0);

// -------------------------------
// Helpers
// -------------------------------
~jit_CF_sideToProxy = { |side|
    var sym;
    sym = if(side == \A) { \outA } { \outB };
    sym
};

~jitCFGetInactiveSide = {
    var active;
    active = ~jitCFActiveSide ? \A;
    if(active == \A) { \B } { \A }
};

// Ensure the crossfade mixer lives in Ndef(\out); centralizes fade via VarLag on \mix_pos
~jitSetCrossfade = { |fade = nil, tail = nil|
    var f, t, mixFunc, initMix, active;
    f = if(fade.notNil) { fade } { (~jitCFFadeTime.notNil).if({ ~jitCFFadeTime }, { 0.08 }) };
    t = if(tail.notNil) { tail } { (~jitCFTailTime.notNil).if({ ~jitCFTailTime }, { 0.25 }) };

    mixFunc = {
        var a, b, pos;
        a = Ndef.ar(\outA);
        b = Ndef.ar(\outB);
        // VarLag honors language-side fade time on \mix_pos
        pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(f));
        XFade2.ar(a, b, pos)
    };

    Ndef(\out).source = mixFunc;

    // Side proxies shouldn't add their own ramping; we manage fades at the mixer.
    Ndef(\outA).fadeTime = 0.0;
    Ndef(\outB).fadeTime = 0.0;

    ~jitXFadeInstalled = true;
    ~jitCFFadeTime = f;
    ~jitCFTailTime = t;

    // Initialize mix position to current active side
    active = ~jitCFActiveSide ? \A;
    initMix = if(active == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, initMix, \mix_lag, f);
};

// Only install mixer if missing (doesn't overwrite if already present)
~jitCFEnsureMixer = {
    var has;
    has = Ndef(\out).source.notNil;
    if(has.not) { ~jitSetCrossfade.(~jitCFFadeTime, ~jitCFTailTime) };
};

// -------------------------------
// Debounced inactive-side build (no clear+put; no .value)
// -------------------------------
~jitBuildCF = { |side, spec|
    var sideSym, proxy, isValid, isSame, scheduleBuild;

    sideSym = ~jit_CF_sideToProxy.(side);
    proxy = Ndef(sideSym);

    // Validate spec if checker exists (no-ops if not provided)
    isValid = true;
    if(~jitIsValidSpec.notNil) { isValid = ~jitIsValidSpec.(spec) };
    if(isValid.not) {
        // skip invalid spec to avoid server churn
    }{
        // Skip if latest spec already matches AND proxy already has a source
        isSame = ((~jitCFBuildLatest[sideSym] == spec) and: { proxy.source.notNil });
        if(isSame.not) {
            ~jitCFBuildLatest[sideSym] = spec;

            if(~jitCFDebounceRunning[sideSym] ? false) {
                // already scheduled; just updated latest spec
            }{
                ~jitCFDebounceRunning[sideSym] = true;
                ~jitCFBuildPending[sideSym] = true;

                scheduleBuild = {
                    var s, f;
                    s = ~jitCFBuildLatest[sideSym];
                    f = ~jitMakeChainFunc.(s);

                    if(f.notNil) {
                        // IMPORTANT: do not call f.value — assign the function so Ndef builds inside SynthDef context.
                        proxy.source = f;
                        proxy.play;
                        proxy.set(\gate, 1);
                        ~jitCFGates[sideSym] = 1;
                    };

                    ~jitCFDebounceRunning[sideSym] = false;
                    ~jitCFBuildPending[sideSym] = false;
                    0
                };

                AppClock.sched(~jitCFDebounceSec, scheduleBuild);
            };
        };
    };
};

// -------------------------------
// Crossfade
// -------------------------------
~jitStartCrossfadeTo = { |toSide, fade = nil, tail = nil|
    var f, t, toSym, fromSide, fromSym, toProxy, fromProxy, mixTo, token, clearAfter;

    f = if(fade.notNil) { fade } { (~jitCFFadeTime.notNil).if({ ~jitCFFadeTime }, { 0.08 }) };
    t = if(tail.notNil) { tail } { (~jitCFTailTime.notNil).if({ ~jitCFTailTime }, { 0.25 }) };

    ~jitCFEnsureMixer.();

    toSym = ~jit_CF_sideToProxy.(toSide);
    fromSide = if(toSide == \A) { \B } { \A };
    fromSym = ~jit_CF_sideToProxy.(fromSide);
    toProxy = Ndef(toSym);
    fromProxy = Ndef(fromSym);

    // Ensure target is hot during the entire fade
    toProxy.set(\gate, 1);
    ~jitCFGates[toSym] = 1;

    // Move mixer towards target side: -1 (A), +1 (B)
    mixTo = if(toSide == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, mixTo, \mix_lag, f);

    ~jitCFActiveSide = toSide;

    // After fade completes, fade out the losing side by gating to 0
    AppClock.sched(f, {
        fromProxy.set(\gate, 0);
        ~jitCFGates[fromSym] = 0;
        0
    });

    // Token-guarded delayed stop: only latest switch cleans up the loser
    ~jitCFStopTokenCounter = (~jitCFStopTokenCounter ? 0) + 1;
    token = ~jitCFStopTokenCounter;
    ~jitCFStopToken[fromSym] = token;

    clearAfter = {
        var stillValid, pending;
        stillValid = (~jitCFStopToken[fromSym] == token);
        pending = ~jitCFBuildPending[fromSym] ? false;

        // Skip stop if a rebuild for this side is pending (prevents churn & races)
        if(stillValid and: { pending.not }) {
            fromProxy.stop; // less churn than .clear; avoids temp def races
        };
        0
    };

    AppClock.sched(f + t, clearAfter);
};

// -------------------------------
// Preview / Switch API
// -------------------------------
~jitCFPreview = { |spec|
    var curSide, side, isValid, changed;

    // Validate spec if checker exists
    isValid = true;
    if(~jitIsValidSpec.notNil) { isValid = ~jitIsValidSpec.(spec) };

    if(isValid.not) {
        // skip invalid
    }{
        // Determine inactive side without async .get
        curSide = ~jitCFActiveSide ? \A;
        side = if(curSide == \A) { \B } { \A };

        // Only update if spec changed
        changed = (~jitNextSpec == spec).not;
        if(changed) {
            ~jitNextSpec = spec;

            // GUI refresh on next tick (guarded)
            AppClock.sched(0, {
                if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
                0
            });

            // Debounced build on inactive side
            AppClock.sched(0, {
                ~jitBuildCF.(side, spec);
                0
            });
        };
    };
};

~jitCFSwitchNow = {
    var newSpec, targetSide, f, t;
    var will, did;

    // Read fade/tail
    f = (~jitCFFadeTime.notNil).if({ ~jitCFFadeTime }, { 0.08 });
    t = (~jitCFTailTime.notNil).if({ ~jitCFTailTime }, { 0.25 });

    // Adopt Next if present; else re-affirm current
    newSpec = ~jitNextSpec ? ~jitCurrentSpec;
    ~jitCurrentSpec = newSpec;
    ~jitNextSpec = nil;

    // Notifications (guarded)
    will = ~jitNotifyWillSwitch;
    if(will.notNil) { will.(newSpec) };

    // DSP switch to inactive side (preview should have built there)
    targetSide = ~jitCFGetInactiveSide.();
    ~jitStartCrossfadeTo.(targetSide, f, t);

    // GUI refresh + didSwitch on next tick
    did = ~jitNotifyDidSwitch;
    AppClock.sched(0, {
        if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
        if(did.notNil) { did.(newSpec) };
        0
    });
};

~jitCFSwitchIn = { |sec = 0.5|
    var t;
    t = sec.max(0.0);
    AppClock.sched(t, {
        ~jitCFSwitchNow.();
        0
    });
};

// -------------------------------
// Adapter mapping (idempotent)
// -------------------------------
~jitCFAdapter = ~jitCFAdapter ? IdentityDictionary.new;
~jitCFAdapter.putAll((
    buildInactive: { |side, spec| ~jitBuildCF.(side, spec) },
    switchNow:    { ~jitCFSwitchNow.() },
    switchIn:     { |sec = 0.5| ~jitCFSwitchIn.(sec) }
));

// Optionally ensure mixer is present at load (safe: renders silence until sides are built)
~jitCFEnsureMixer.();

)
