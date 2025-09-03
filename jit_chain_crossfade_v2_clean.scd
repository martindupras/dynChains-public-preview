// jit_chain_crossfade_v2_clean.scd
// Crossfade layer for v2 (clean, idempotent, no server.sync).
// - Mixer: Ndef(\out) crossfades between Ndef(\outA) and Ndef(\outB) by \mix_pos (-1=A, +1=B)
// - Gates: \chainA_gate / \chainB_gate (set to 0 on the old chain when switching)
// - State: ~jitCFEnabled (bool), ~jitCF (fadeTime, tailHold), ~jitActiveChain (\A|\B)
// - Notifications: uses ~jitOnRebuildNotify if defined (willBuild/didBuild, willSwitch/didSwitch)

(
/* ────────────────────────────────────────────────────────────────────────── */
/* 0) State & defaults                                                       */
/* ────────────────────────────────────────────────────────────────────────── */
~jitCFEnabled   = ~jitCFEnabled   ? false;
~jitActiveChain = ~jitActiveChain ? \A;

// Compact settings; use ~jitFadeTime when present
~jitCF = ~jitCF ? (
    fadeTime: (~jitFadeTime ? 0.25),
    tailHold: 2.0
);

// No‑op notify if the bridge is not loaded yet
~jitOnRebuildNotify = ~jitOnRebuildNotify ? { |phase, payload| };

/* ────────────────────────────────────────────────────────────────────────── */
/* 1) Small helpers                                                          */
/* ────────────────────────────────────────────────────────────────────────── */
~cfInactiveChain = { |active|
    var a; a = active ? \A;
    (a == \A).if({ \B }, { \A })
};

~cfChainKey  = { |which| ("chain" ++ which.asString).asSymbol };
~cfOutKey    = { |which| ("out"   ++ which.asString).asSymbol };
~cfGateKey   = { |which| ("chain" ++ which.asString ++ "_gate").asSymbol };

/* ────────────────────────────────────────────────────────────────────────── */
/* 2) Mixer: Ndef(\out) ← crossfade( Ndef(\outA), Ndef(\outB) )               */
/*    - \mix_pos in [-1 .. +1], lagged by ~jitCF.fadeTime                    */
/*    - Idempotent (re-assigns the function; keeps your bus selection)       */
/* ────────────────────────────────────────────────────────────────────────── */
~jitEnsureCFMixer = {
    var fade;
    fade = ~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25);

    // Ensure holders exist (you will feed them from your build layer)
    Ndef(~cfOutKey.(\A));  // creates if missing
    Ndef(~cfOutKey.(\B));

    // Output mixer
    Ndef(\out).source = {
        var a, b, pos, lagPos, outSig;
        a = Ndef.ar(~cfOutKey.(\A));
        b = Ndef.ar(~cfOutKey.(\B));
        // Default to A (−1) at startup
        pos    = NamedControl.kr(\mix_pos, -1);
        lagPos = Lag.kr(pos, fade);
        outSig = XFade2.ar(a, b, lagPos);  // multichannel-safe
        outSig
    };
    Ndef(\out).fadeTime = ~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25);
};

/* ────────────────────────────────────────────────────────────────────────── */
/* 3) Public API: enable/disable crossfade                                   */
/* ────────────────────────────────────────────────────────────────────────── */
~jitSetCrossfade = { |fade, tail|
    var f, t;
    f = fade ? (~jitFadeTime ? 0.25);
    t = tail ? 2.0;
    ~jitCF[\fadeTime] = f;
    ~jitCF[\tailHold] = t;
    ~jitCFEnabled = true;
    ~jitEnsureCFMixer.();
};

~jitDisableCrossfade = {
    ~jitCFEnabled = false;
    // Keep mixer/proxies as-is (non-destructive)
};

/* ────────────────────────────────────────────────────────────────────────── */
/* 4) Start crossfade to target chain (A|B).                                  */
/*    - No server.sync (non-blocking)                                         */
/*    - Uses \mix_pos.lag and gates                                           */
/*    - Schedules free of old chain/out after fade+tail                       */
/* ────────────────────────────────────────────────────────────────────────── */
~jitFreeTask = ~jitFreeTask ? nil;

~jitStartCrossfadeTo = { |target|
    var fromSym, toSym, fade, tail, oldGateKey, fromChain, fromOut, mixPos;
    var notify;

    // declare here to keep var-first style
    notify = ~jitOnRebuildNotify;

    fromSym = ~jitActiveChain ? \A;
    toSym   = target.isNil.if({ ~cfInactiveChain.(fromSym) }, { target.asSymbol });

    fade = ~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25);
    tail = ~jitCF[\tailHold] ? 2.0;

    oldGateKey = ~cfGateKey.(fromSym);
    fromChain  = ~cfChainKey.(fromSym);
    fromOut    = ~cfOutKey.(fromSym);

    // Notify listeners (willSwitch)
    notify.(\willSwitch, (from: fromSym, to: toSym, fade: fade, tail: tail));

    // Ensure mixer is present
    ~jitEnsureCFMixer.();

    // Move mixer to the target side (-1 → A, +1 → B); lag handles the fade
    mixPos = (toSym == \A).if({ -1 }, { 1 });
    Ndef(\out).set(\mix_pos, mixPos);

    // Stop feeding the old chain (assumes your chain uses *_gate)
    Ndef(fromChain).set(oldGateKey, 0);

    // Cancel any previous pending free
    ~jitFreeTask.notNil.if({
        ~jitFreeTask.stop;
        ~jitFreeTask = nil;
    });

    // Free old chain & its out after fade + tail
    ~jitFreeTask = AppClock.sched(fade + tail, {
        Ndef(fromOut).clear;     // clear proxy feeding mixer
        Ndef(fromChain).clear;   // clear chain processing
        ~jitFreeTask = nil;
        nil
    });

    // Update state
    ~jitActiveChain = toSym;
    ~jitCurrentSpec = ~jitNextSpec ?? { ~jitCurrentSpec };
    ~jitNextSpec = nil;

    // Notify listeners (didSwitch)
    notify.(\didSwitch, (active: ~jitActiveChain, spec: ~jitCurrentSpec));
};

/* ────────────────────────────────────────────────────────────────────────── */
/* 5) Build with crossfade:                                                   */
/*    - If ~jitBuildIntoChain exists -> use it; else, warn and fall back      */
/*    - In either case, will call ~jitStartCrossfadeTo when ready             */
/* ────────────────────────────────────────────────────────────────────────── */
~jitBuildCF = { |spec|
    var inactive, notify, haveInto;
    notify   = ~jitOnRebuildNotify;
    haveInto = ~jitBuildIntoChain.notNil;

    (~jitCFEnabled.not).if({
        // No CF: legacy path
        ~jitBuild.(spec);
    }, {
        // CF: build into inactive chain then crossfade to it
        ~jitEnsureCFMixer.();
        inactive = ~cfInactiveChain.(~jitActiveChain ? \A);

        notify.(\willBuild, (spec: spec, inactive: inactive));

        haveInto.if({
            ~jitNextSpec = spec;
            ~jitBuildIntoChain.(spec, inactive);  // your core must feed Ndef(\out<inactive>)
            notify.(\didBuild, (inactive: inactive, spec: spec));
            ~jitStartCrossfadeTo.(inactive);
        }, {
            // Fallback (single chain): warn once and use legacy ~jitBuild
            (~jitBuildCFWarned ? false).if({
                "[jit CF] ~jitBuildIntoChain is missing; falling back to ~jitBuild (no crossfade)".warn;
                ~jitBuildCFWarned = true;
            });
            ~jitBuild.(spec);
        });
    });
};
)
