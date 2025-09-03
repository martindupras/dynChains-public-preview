// jit_chain_crossfade_v3_clean.scd
// Self-contained v3 crossfade with compatibility keys expected elsewhere:
//   ~jitCF[\fadeTime], ~jitCF[\tailHold], ~jitActiveChain, ~jitCFEnabled

(
// --- Compatibility / state (initialize once) ---
~jitCF         = (~jitCF         ? IdentityDictionary.newFrom([ \fadeTime, 1.0, \tailHold, 0.5 ]));
~jitCFEnabled  = (~jitCFEnabled  ? false);
~jitActiveChain= (~jitActiveChain? \A);   // \A or \B
// --- Crossfade mixer setup ---
~jitSetCrossfade = { |fade = 1.0, tail = 0.5|
    var mixPos;
    mixPos = \mix_pos;

    // keep compatibility state in sync
    ~jitCF[\fadeTime] = fade;
    ~jitCF[\tailHold] = tail;
    ~jitCFEnabled = true;

    Ndef(\out).fadeTime = 0;
    Ndef(\out).put(0, {
        var a, b, mix;
        a = Ndef(\outA).ar;   // may be silent until chains are built
        b = Ndef(\outB).ar;
        mix = mixPos.kr(0).lag(fade);
        XFade2.ar(a, b, (mix * 2) - 1)
    });

    Ndef(\out).set(mixPos, 0);
    // Retain legacy tail var if other code uses it
    ~jitCrossfadeTail = tail;
};

// --- Start crossfade to the target chain (\A or \B) ---
~jitStartCrossfadeTo = { |target, fade = nil, tail = nil|
    var other, gateKey, otherGateKey, tailTime, fadeTime, valid;
    valid = [\A, \B];

    if (valid.includes(target).not) { "Invalid crossfade target: %".format(target).warn; ^nil };

    fadeTime = fade ?? { ~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25) };
    tailTime = tail ?? { ~jitCF[\tailHold] ? 0.5 };

    other = (target == \A).if(\B, \A);
    gateKey      = ("chain" ++ target.asString ++ "_gate").asSymbol;
    otherGateKey = ("chain" ++ other.asString ++ "_gate").asSymbol;

    ~jitActiveChain = target;

    Ndef(\out).set(\mix_pos, (target == \A).if(0, 1));
    Ndef(("out" ++ target.asString).asSymbol).set(gateKey, 1);         // ensure target open
    Ndef(("out" ++ other.asString).asSymbol).set(otherGateKey, 0);     // ensure other closed

    SystemClock.sched(fadeTime + tailTime, {
        Ndef(("out" ++ other.asString).asSymbol).clear;
        nil
    });
};

/*~jitStartCrossfadeTo = { |target, fade = nil, tail = nil|
    var other, gateKey, otherGateKey, tailTime, fadeTime, valid;
    valid = [\A, \B];

    if (valid.includes(target).not) {
        "Invalid crossfade target: %".format(target).warn;
        ^nil;
    };

    // resolve times with sensible fallbacks
    fadeTime = fade ?? { ~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25) };
    tailTime = tail ?? { ~jitCF[\tailHold] ? 0.5 };

    other = (target == \A).if(\B, \A);
    gateKey = ("chain" ++ target.asString ++ "_gate").asSymbol;
    otherGateKey = ("chain" ++ other.asString ++ "_gate").asSymbol;

    ~jitActiveChain = target;

    Ndef(\out).set(\mix_pos, (target == \A).if(0, 1));
    //Ndef(\out).set(otherGateKey, 0);
	Ndef(("out" ++ other.asString).asSymbol).set(otherGateKey, 0);


    SystemClock.sched(fadeTime + tailTime, {
        Ndef(("out" ++ other.asString).asSymbol).clear;
        nil
    });
};*/

// --- Build a chain into its side (A or B) with a simple gate ---
// --- Build a chain into its side (A or B) with a simple gate ---
~jitBuildCF = { |which, spec|
    var buildFunc, gateKey, out;

    buildFunc = (~jitBuildIntoChain.isFunction).if({
        ~jitBuildIntoChain
    },{
        { |w, s|
            // NOTE: .warnOnce is not standard; use .warn as a minimal fix.
            "No ~jitBuildIntoChain defined. Falling back to ~jitBuild.".warn;

            // Fallback: if ~jitBuild is a function that returns a UGen func, use it;
            // otherwise return silence to avoid breaking the CF mixer.
            out = (~jitBuild.isFunction).if({ ~jitBuild.(s) }, { nil });
            out ? 0.0
        }
    });

    gateKey = ("chain" ++ which.asString ++ "_gate").asSymbol;

    Ndef(("out" ++ which.asString).asSymbol).clear;
    Ndef(("out" ++ which.asString).asSymbol).put(0, {
        var sig;
        //sig = buildFunc.(which, spec);
		sig = buildFunc.(which, spec).value;  // IMPORTANT: evaluate the returned
        sig = sig * gateKey.kr(1);
        sig
    });
    Ndef(("out" ++ which.asString).asSymbol).set(gateKey, 1);

    ~jitCFEnabled = true;
};


/* --- Crossfade engine (v3 clean, minimal) --- */

/* Side -> proxy mapping helper */
~jit_CF_sideToProxy = { |side|
    var sym;
    sym = if(side == \A) { \outA } { \outB };
    sym
};

/* Install/ensure the XFade mixer on Ndef(\out). Keeps VarLag on \mix_pos to honor fade times. */
/*~jitSetCrossfade = { |fade = 0.05, tail = 0.20|
    var mixFunc, initMix, active;

    mixFunc = {
        var a, b, pos;
        a = Ndef.ar(\outA);
        b = Ndef.ar(\outB);
        pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(fade));
        XFade2.ar(a, b, pos)
    };

    Ndef(\out).source = mixFunc;

    // Avoid side proxy internal fades/ramp spawns; we control fade centrally via mixer
    Ndef(\outA).fadeTime = 0.0;
    Ndef(\outB).fadeTime = 0.0;

    ~jitXFadeInstalled = true;
    ~jitCFFade = fade;
    ~jitCFTail = tail;

    active = ~jitCFActiveSide ? \A;
    initMix = (active == \A) ? -1 : 1;
    Ndef(\out).set(\mix_pos, initMix, \mix_lag, fade);
};*/
~jitSetCrossfade = { |fade = 0.05, tail = 0.20|
    var mixFunc, initMix, active;

    mixFunc = {
        var a, b, pos;
        a = Ndef.ar(\outA);
        b = Ndef.ar(\outB);
        pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(fade));
        XFade2.ar(a, b, pos)
    };

    Ndef(\out).source = mixFunc;

    // Avoid side proxy internal fades/ramp spawns; we control fade centrally via mixer
    Ndef(\outA).fadeTime = 0.0;
    Ndef(\outB).fadeTime = 0.0;

    ~jitXFadeInstalled = true;
    ~jitCFFade = fade;
    ~jitCFTail = tail;

    active = ~jitCFActiveSide ? \A;
    initMix = if(active == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, initMix, \mix_lag, fade);
};


/* Debounce bookkeeping */
~jitCFDebounceSec = ~jitCFDebounceSec ? 0.05;
~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;      // \outA -> spec, \outB -> spec
~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new; // \outA/\outB -> boolean
~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;    // \outA/\outB -> boolean
~jitCFGates = ~jitCFGates ? IdentityDictionary.new;                  // \outA/\outB -> 0/1
~jitCFStopToken = ~jitCFStopToken ? IdentityDictionary.new;          // \outA/\outB -> int
~jitCFStopTokenCounter = ~jitCFStopTokenCounter ? 0;

/* Build inactive side with debounce and without clear+put churn */
/* Build inactive side with debounce and without clear+put churn */
~jitBuildCF = { |side, spec|
    var sideSym, scheduleBuild;

    sideSym = ~jit_CF_sideToProxy.(side);
    ~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;
    ~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new;
    ~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;
    ~jitCFGates = ~jitCFGates ? IdentityDictionary.new;
    ~jitCFDebounceSec = ~jitCFDebounceSec ? 0.05;

    ~jitCFBuildLatest[sideSym] = spec;

    if(~jitCFDebounceRunning[sideSym] ? false) {
        // already scheduled; latest spec stored
    }{
        ~jitCFDebounceRunning[sideSym] = true;
        ~jitCFBuildPending[sideSym] = true;

        scheduleBuild = {
            var s, f, proxy;
            s = ~jitCFBuildLatest[sideSym];
            proxy = Ndef(sideSym);

            f = ~jitMakeChainFunc.(s);
            if(f.notNil) {
                // DO NOT call f.value here; let Ndef compile this inside a SynthDef build
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

/*~jitBuildCF = { |side, spec|
    var sideSym, scheduleBuild;

    sideSym = ~jit_CF_sideToProxy.(side);
    ~jitCFBuildLatest[sideSym] = spec;

    if(~jitCFDebounceRunning[sideSym] ? false) {
        // already scheduled; latest spec stored, nothing to do
    }{
        ~jitCFDebounceRunning[sideSym] = true;
        ~jitCFBuildPending[sideSym] = true;

        scheduleBuild = {
            var s, f, proxy;
            s = ~jitCFBuildLatest[sideSym];
            proxy = Ndef(sideSym);

            f = ~jitMakeChainFunc.(s);
            if(f.notNil) {
                // No .clear; this keeps /d_recv and /s_new ordering tight on server
                proxy.source = f.value;
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
};*/

/* Begin crossfade to target side.
   - Ensure mixer exists.
   - Set target gate=1 immediately.
   - Ramp mix_pos over 'fade'.
   - After fade: set loser gate=0.
   - After fade+tail: stop loser (token-guarded), unless a rebuild is pending. */

~jitStartCrossfadeTo = { |toSide, fade, tail|
    var toSym, fromSide, fromSym, toProxy, fromProxy, f, t, mixTo, token, clearAfter;

    f = fade ? (~jitCFFade ? 0.05);
    t = tail ? (~jitCFTail ? 0.20);

    if(Ndef(\out).source.isNil) {
        ~jitSetCrossfade.(f, t);
    };

    toSym = ~jit_CF_sideToProxy.(toSide);
    fromSide = if(toSide == \A) { \B } { \A };
    fromSym = ~jit_CF_sideToProxy.(fromSide);
    toProxy = Ndef(toSym);
    fromProxy = Ndef(fromSym);

    // Ensure target is hot during the entire fade
    toProxy.set(\gate, 1);
    ~jitCFGates[toSym] = 1;

    // Move mixer towards target side
    mixTo = if(toSide == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, mixTo, \mix_lag, f);

    ~jitCFActiveSide = toSide;

    // After fade completes, fade out the losing side by gating to 0
    AppClock.sched(f, {
        fromProxy.set(\gate, 0);
        ~jitCFGates[fromSym] = 0;
        0
    });

    // Token-guarded delayed stop: only the latest switch clears/stops the loser
    ~jitCFStopTokenCounter = (~jitCFStopTokenCounter ? 0) + 1;
    token = ~jitCFStopTokenCounter;
    ~jitCFStopToken[fromSym] = token;

    clearAfter = {
        var stillValid, pending;
        stillValid = (~jitCFStopToken[fromSym] == token);
        pending = ~jitCFBuildPending[fromSym] ? false;

        // Skip stop if a rebuild for this side is pending (churn prevention)
        if(stillValid and: { pending.not }) {
            fromProxy.stop; // less churn than .clear; avoids temp def races
        };
        0
    };

    AppClock.sched(f + t, clearAfter);
};


/* --- (Optional) Adapter merged (idempotent) --- */
~jitCFAdapter = ~jitCFAdapter ? IdentityDictionary.new;
~jitCFAdapter.putAll((
    buildInactive: { |side, spec| ~jitBuildCF.(side, spec) },
    switchNow: { ~jitCFSwitchNow.() },
    switchIn: { |sec = 0.5| ~jitCFSwitchIn.(sec) }
));


// --- Optional: install the mixer with defaults immediately ---
// Safe even if outA/outB aren't defined yet; they'll render silence until built.
~jitSetCrossfade.(~jitCF[\fadeTime], ~jitCF[\tailHold]);

/* Preview into the inactive side:
   - Synchronously set ~jitNextSpec (so GUI/tests see it immediately),
   - Schedule the debounced build on the inactive side,
   - Trigger a single GUI refresh on the next AppClock tick. */

/* Preview into the inactive side:
   - Synchronously set ~jitNextSpec (deterministic for GUI/tests),
   - Schedule the debounced build on the inactive side,
   - Trigger a single GUI refresh next tick. */
~jitCFPreview = { |spec|
    var curSide, side, sideSym;

    curSide = ~jitCFActiveSide ? \A;
    side = if(curSide == \A) { \B } { \A };
    sideSym = ~jit_CF_sideToProxy.(side);

    // Update 'Next' immediately
    ~jitNextSpec = spec;

    // Optional didPreview notification
    if(~jitNotifyDidPreview.notNil) { ~jitNotifyDidPreview.(spec) };

    // GUI refresh on next tick (keeps draw order deterministic)
    AppClock.sched(0, {
        if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
        0
    });

    // Build inactive side (debounced)
    AppClock.sched(0, {
        ~jitBuildCF.(side, spec);
        0
    });
};


/* --- Crossfade engine (v3 clean, patched returns) --- */

~jit_CF_sideToProxy = { |side| if(side == \A) { \outA } { \outB } };

~jitSetCrossfade = { |fade = 0.05, tail = 0.20|
    var mixFunc, initMix, active;

    mixFunc = {
        var a, b, pos;
        a = Ndef.ar(\outA);
        b = Ndef.ar(\outB);
        pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(fade));
        XFade2.ar(a, b, pos)
    };

    Ndef(\out).source = mixFunc;

    Ndef(\outA).fadeTime = 0.0;
    Ndef(\outB).fadeTime = 0.0;

    ~jitXFadeInstalled = true;
    ~jitCFFade = fade;
    ~jitCFTail = tail;

    active = ~jitCFActiveSide ? \A;
    initMix = if(active == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, initMix, \mix_lag, fade);
};

/* Debounce state */
~jitCFDebounceSec = ~jitCFDebounceSec ? 0.08;
~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;
~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new;
~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;
~jitCFGates = ~jitCFGates ? IdentityDictionary.new;
~jitCFStopToken = ~jitCFStopToken ? IdentityDictionary.new;
~jitCFStopTokenCounter = ~jitCFStopTokenCounter ? 0;

/* Guarded preview (valid + changed only); sets Next synchronously */
~jitCFPreview = { |spec|
    var curSide, side, isValid, changed;

    isValid = true;
    if(~jitIsValidSpec.notNil) { isValid = ~jitIsValidSpec.(spec) };
    if(isValid.not) {
        // skip invalid
    }{
        curSide = ~jitCFActiveSide ? \A;
        side = if(curSide == \A) { \B } { \A };

        changed = (~jitNextSpec == spec).not;
        if(changed) {
            ~jitNextSpec = spec;

            AppClock.sched(0, {
                if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
                nil  // <-- run once
            });

            AppClock.sched(0, {
                ~jitBuildCF.(side, spec);
                nil  // <-- run once
            });
        };
    };
};

/* Build inactive side (debounced), skip invalid/unchanged; assign function (no .value) */
~jitBuildCF = { |side, spec|
    var sideSym, proxy, isValid, isSame, scheduleBuild;

    sideSym = ~jit_CF_sideToProxy.(side);
    proxy = Ndef(sideSym);

    ~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;
    ~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new;
    ~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;
    ~jitCFGates = ~jitCFGates ? IdentityDictionary.new;
    ~jitCFDebounceSec = ~jitCFDebounceSec ? 0.08;

    isValid = true;
    if(~jitIsValidSpec.notNil) { isValid = ~jitIsValidSpec.(spec) };
    if(isValid.not) {
        // skip invalid
    }{
        isSame = ((~jitCFBuildLatest[sideSym] == spec) and: { proxy.source.notNil });
        if(isSame.not) {
            ~jitCFBuildLatest[sideSym] = spec;

            if(~jitCFDebounceRunning[sideSym] ? false) {
                // already scheduled; latest stored
            }{
                ~jitCFDebounceRunning[sideSym] = true;
                ~jitCFBuildPending[sideSym] = true;

                scheduleBuild = {
                    var s, f;
                    s = ~jitCFBuildLatest[sideSym];
                    f = ~jitMakeChainFunc.(s);

                    if(f.notNil) {
                        proxy.source = f;   // <-- no .value
                        proxy.play;
                        proxy.set(\gate, 1);
                        ~jitCFGates[sideSym] = 1;
                    };

                    ~jitCFDebounceRunning[sideSym] = false;
                    ~jitCFBuildPending[sideSym] = false;
                    nil  // <-- run once
                };

                AppClock.sched(~jitCFDebounceSec, scheduleBuild);
            };
        };
    };
};

/* Crossfade; schedule blocks return nil */
~jitStartCrossfadeTo = { |toSide, fade, tail|
    var toSym, fromSide, fromSym, toProxy, fromProxy, f, t, mixTo, token, clearAfter;

    f = fade ? (~jitCFFade ? 0.05);
    t = tail ? (~jitCFTail ? 0.20);

    if(Ndef(\out).source.isNil) { ~jitSetCrossfade.(f, t) };

    toSym = ~jit_CF_sideToProxy.(toSide);
    fromSide = if(toSide == \A) { \B } { \A };
    fromSym = ~jit_CF_sideToProxy.(fromSide);
    toProxy = Ndef(toSym);
    fromProxy = Ndef(fromSym);

    toProxy.set(\gate, 1);
    ~jitCFGates[toSym] = 1;

    mixTo = if(toSide == \A) { -1 } { 1 };
    Ndef(\out).set(\mix_pos, mixTo, \mix_lag, f);

    ~jitCFActiveSide = toSide;

    AppClock.sched(f, {
        fromProxy.set(\gate, 0);
        ~jitCFGates[fromSym] = 0;
        nil  // <-- run once
    });

    ~jitCFStopTokenCounter = (~jitCFStopTokenCounter ? 0) + 1;
    token = ~jitCFStopTokenCounter;
    ~jitCFStopToken[fromSym] = token;

    clearAfter = {
        var stillValid, pending;
        stillValid = (~jitCFStopToken[fromSym] == token);
        pending = ~jitCFBuildPending[fromSym] ? false;
        if(stillValid and: { pending.not }) { fromProxy.stop };
        nil  // <-- run once
    };

    AppClock.sched(f + t, clearAfter);
};

/* Adapter (unchanged) */
~jitCFAdapter = ~jitCFAdapter ? IdentityDictionary.new;
~jitCFAdapter.putAll((
    buildInactive: { |side, spec| ~jitBuildCF.(side, spec) },
    switchNow: { ~jitCFSwitchNow.() },
    switchIn: { |sec = 0.5| ~jitCFSwitchIn.(sec) }
));



("[jit] jit_chain_crossfade_v3_clean ready — fade %, tail %, active %, enabled %"
    .format(~jitCF[\fadeTime], ~jitCF[\tailHold], ~jitActiveChain, ~jitCFEnabled)).postln;


)
