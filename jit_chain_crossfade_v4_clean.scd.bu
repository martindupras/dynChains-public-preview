// --------------------------------------------------------------------
// jit_chain_crossfade_v4_clean.scd
// Clean v4 crossfade engine: no clear+put churn, debounced builds,
// robust switch ordering, and adapter mapping (idempotent).
// --------------------------------------------------------------------

(
// =========================
// Global CF state (v4)
// =========================
~jitCF = ~jitCF ? IdentityDictionary.new;
~jitCF[\fadeTime] = ~jitCF[\fadeTime] ? 0.08;   // default fade
~jitCF[\tailHold] = ~jitCF[\tailHold] ? 0.25;   // default tail/hold

~jitCFActiveSide = ~jitCFActiveSide ? \A;       // \A or \B (language-side truth)
~jitCFFadeTime   = ~jitCFFadeTime   ? ~jitCF[\fadeTime];
~jitCFTailTime   = ~jitCFTailTime   ? ~jitCF[\tailHold];

~jitCFDebounceSec = ~jitCFDebounceSec ? 0.08;   // collapse rapid rebuilds
~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;         // \outA/\outB -> spec
~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new; // side -> bool
~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;       // side -> bool
~jitCFGates = ~jitCFGates ? IdentityDictionary.new;                     // \outA/\outB -> 0/1
~jitCFStopToken = ~jitCFStopToken ? IdentityDictionary.new;             // \outA/\outB -> token
~jitCFStopTokenCounter = ~jitCFStopTokenCounter ? 0;

~jitXFadeInstalled = ~jitXFadeInstalled ? false;


// =========================
// Helpers
// =========================

/* Side -> proxy symbol */
~jit_CF_sideToProxy = { |side|
    var sym;
    sym = if(side == \A) { \outA } { \outB };
    sym
};

/* Quick spec validator: use user's validator when present, else a minimal check */
~jitCF_isValidSpec = { |spec|
    var ok, last;
    ok = true;
    if(~jitIsValidSpec.notNil) {
        ok = ~jitIsValidSpec.(spec);
    }{
        ok = spec.notNil and: { spec.isArray } and: { spec.size >= 2 };
        if(ok) {
            last = spec.last;
            ok = (last == \destination) or: { last == \destinationStereo };
        };
    };
    ok
};


// =========================
// Mixer install / keep-alive
// =========================

/* Install/ensure the XFade2 mixer on Ndef(\out). Uses VarLag on \mix_pos. */
~jitSetCrossfade = { |fade = 0.08, tail = 0.25|
    var mixFunc, initMix, active;
    ~jitCFFadeTime = fade;
    ~jitCFTailTime = tail;
    ~jitCF[\fadeTime] = fade;
    ~jitCF[\tailHold] = tail;

    mixFunc = {
        var a, b, pos;
        a = Ndef.ar(\outA);   // silent until sources exist
        b = Ndef.ar(\outB);
        pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(fade));
        XFade2.ar(a, b, pos)
    };

    Ndef(\out).source = mixFunc;

    // centralize fades at the mixer
    Ndef(\outA).fadeTime = 0.0;
    Ndef(\outB).fadeTime = 0.0;

    ~jitXFadeInstalled = true;

    active = ~jitCFActiveSide ? \A;
    initMix = if(active == \A) { -1 } { 1 };   // -1 = A, +1 = B
    Ndef(\out).set(\mix_pos, initMix, \mix_lag, fade);
};

/* If mixer gets overwritten, re-assert it with stored fade/tail */
~jitCFEnsureMixer = {
    var needs;
    needs = Ndef(\out).source.isNil or: { ~jitXFadeInstalled.not };
    if(needs) {
        ~jitSetCrossfade.(~jitCFFadeTime ? 0.08, ~jitCFTailTime ? 0.25);
    };
};


// =========================
// Debounced inactive-side build without clear+put churn.
// =========================
~jitBuildCF = { |side, spec|
    var sideSym, proxy, isValid, isSame, scheduleBuild;

    sideSym = ~jit_CF_sideToProxy.(side);
    proxy = Ndef(sideSym);

    isValid = ~jitCF_isValidSpec.(spec);
    if(isValid.not) {
        // skip invalid; quiet
    }{
        isSame = ((~jitCFBuildLatest[sideSym] == spec) and: { proxy.source.notNil });
        if(isSame.not) {
            ~jitCFBuildLatest[sideSym] = spec;

            if(~jitCFDebounceRunning[sideSym] ? false) {
                // already scheduled; latest will be consumed by the pending task
            }{
                ~jitCFDebounceRunning[sideSym] = true;
                ~jitCFBuildPending[sideSym] = true;

                scheduleBuild = {
                    var s, f;
                    s = ~jitCFBuildLatest[sideSym];
                    f = ~jitMakeChainFunc.notNil.if({ ~jitMakeChainFunc.(s) }, { nil });

                    if(f.notNil) {
                        // IMPORTANT: assign function, not f.value
                        proxy.source = f;
                        proxy.play;
                        proxy.set(\gate, 1);
                        ~jitCFGates[sideSym] = 1;
                    };

                    ~jitCFDebounceRunning[sideSym] = false;
                    ~jitCFBuildPending[sideSym] = false;
                    nil  // run once
                };

                AppClock.sched(~jitCFDebounceSec, scheduleBuild);
            };
        };
    };
};


// =========================
// Preview into the inactive side (deterministic).
// =========================
~jitCFPreview = { |spec|
    var curSide, side, changed, valid;

    valid = ~jitCF_isValidSpec.(spec);
    if(valid.not) {
        // quiet skip
    }{
        curSide = ~jitCFActiveSide ? \A;
        side = if(curSide == \A) { \B } { \A };

        changed = (~jitNextSpec == spec).not;
        if(changed) {
            ~jitNextSpec = spec;

            // one-tick GUI refresh (no reschedule)
            { if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() } }.defer;

            // debounced build on inactive side
            { ~jitBuildCF.(side, spec) }.defer;
        };
    };
};


// =========================
// Start crossfade to `toSide`.
// =========================
~jitStartCrossfadeTo = { |toSide, fade, tail|
    var toSym, fromSide, fromSym, toProxy, fromProxy, f, t, mixTo, token, clearAfter;

    f = fade ? (~jitCFFadeTime ? 0.08);
    t = tail ? (~jitCFTailTime ? 0.25);

    ~jitCFEnsureMixer.();

    toSym = ~jit_CF_sideToProxy.(toSide);
    fromSide = if(toSide == \A) { \B } { \A };
    fromSym = ~jit_CF_sideToProxy.(fromSide);
    toProxy = Ndef(toSym);
    fromProxy = Ndef(fromSym);

    // keep target hot through the entire fade
    toProxy.set(\gate, 1);
    ~jitCFGates[toSym] = 1;

    // move the mixer
    mixTo = if(toSide == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, mixTo, \mix_lag, f);

    ~jitCFActiveSide = toSide;

    // after fade: fade out loser
    AppClock.sched(f, {
        fromProxy.set(\gate, 0);
        ~jitCFGates[fromSym] = 0;
        nil  // run once
    });

    // token-guard delayed stop of loser after tail
    ~jitCFStopTokenCounter = (~jitCFStopTokenCounter ? 0) + 1;
    token = ~jitCFStopTokenCounter;
    ~jitCFStopToken[fromSym] = token;

    clearAfter = {
        var stillValid, pending;
        stillValid = (~jitCFStopToken[fromSym] == token);
        pending = ~jitCFBuildPending[fromSym] ? false;

        if(stillValid and: { pending.not }) {
            fromProxy.stop;  // gentler than clear; avoids temp def churn
        };
        nil  // run once
    };

    AppClock.sched(f + t, clearAfter);
};


// =========================
// Immediate / scheduled switch.
// =========================
~jitCFSwitchNow = { |fade = nil, tail = nil|
    var newSpec, targetSide, f, t;

    newSpec = ~jitNextSpec ? ~jitCurrentSpec;
    if(~jitCF_isValidSpec.(newSpec)) {
        f = fade ? (~jitCFFadeTime ? 0.08);
        t = tail ? (~jitCFTailTime ? 0.25);

        ~jitCurrentSpec = newSpec;
        ~jitNextSpec = nil;

        if(~jitNotifyWillSwitch.notNil) { ~jitNotifyWillSwitch.(newSpec) };

        targetSide = if((~jitCFActiveSide ? \A) == \A) { \B } { \A };
        ~jitStartCrossfadeTo.(targetSide, f, t);

        // one-tick GUI & didSwitch (no reschedule)
        {
            if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
            if(~jitNotifyDidSwitch.notNil) { ~jitNotifyDidSwitch.(newSpec) };
        }.defer;
    }{
        // no-op
    };
};

~jitCFSwitchIn = { |sec = 0.5, fade = nil, tail = nil|
    var t, f, tl;
    t = sec.max(0.0);
    f = fade ? (~jitCFFadeTime ? 0.08);
    tl = tail ? (~jitCFTailTime ? 0.25);

    AppClock.sched(t, {
        ~jitCFSwitchNow.(f, tl);
        nil  // run once
    });
};


// =========================
// CF liveness probe (debug)
// =========================
~jitCFAssertLive = {
    var outA, outB, mix, chansA, chansB, gates, gateA, gateB, hasMixer;
    outA = Ndef(\outA);
    outB = Ndef(\outB);
    mix  = Ndef(\out);

    chansA = outA.numChannels ? -1;
    chansB = outB.numChannels ? -1;

    gates = ~jitCFGates ? IdentityDictionary.new;
    gateA = gates[\outA] ? 'unknown';
    gateB = gates[\outB] ? 'unknown';

    hasMixer = mix.source.notNil;

    ("[CF Assert] outA chans=% gate=%  |  outB chans=% gate=%".format(chansA, gateA, chansB, gateB)).postln;
    ("[CF Assert] mixer present? " ++ hasMixer).postln;
};


// =========================
// Adapter mapping (idempotent)
// =========================
~jitCFAdapter = ~jitCFAdapter ? IdentityDictionary.new;
~jitCFAdapter.putAll((
    buildInactive: { |spec| ~jitCFPreview.(spec) },
    switchNow:    { ~jitCFSwitchNow.() },
    switchIn:     { |sec = 0.5| ~jitCFSwitchIn.(sec) }
));


// =========================
// Optional: assert mixer on load
// =========================
~jitCFEnsureMixer.();

) // end block
