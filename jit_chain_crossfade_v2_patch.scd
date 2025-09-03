// jit_chain_crossfade_v2_patch.scd
// Patch for your crossfade layer:
// - No identifiers starting with underscore
// - Remove server.sync (no Routine required)
// - Guard target symbol; default to inactive chain

(
~jitActiveChain     = ~jitActiveChain     ?? { \A };
~jitCFEnabled       = ~jitCFEnabled       ?? { false };
~jitCF              = ~jitCF              ?? { (fadeTime: (~jitFadeTime ? 0.25), tailHold: 2.0) };
~jitFreeTask        = ~jitFreeTask        ?? { nil };
~jitOnRebuildNotify = ~jitOnRebuildNotify ?? { |phase, payload| };

// Helper: which chain is inactive relative to the active one?
~cfInactiveChain = { |active|
    var a;
    a = active ? \A;
    (a == \A).if({ \B }, { \A })
};

// SAFER crossfade: no server.sync, validate target
~jitStartCrossfadeTo = { |targetSym|
    var fromSym, toSym, fade, tail;
    var oldGateKey, mixPos, fromChainSym, fromOutSym;

    fromSym = ~jitActiveChain ? \A;
    toSym   = targetSym.isNil.if({ ~cfInactiveChain.(fromSym) }, { targetSym.asSymbol });

    fade = ~jitCF.fadeTime ? (~jitFadeTime ? 0.25);
    tail = ~jitCF.tailHold ? 2.0;

    oldGateKey   = (("chain" ++ fromSym.asString ++ "_gate").asSymbol);
    fromChainSym = (("chain" ++ fromSym.asString).asSymbol);
    fromOutSym   = (("out"   ++ fromSym.asString).asSymbol);

    // 1) notify
    ~jitOnRebuildNotify.(\willSwitch, (from: fromSym, to: toSym, fade: fade, tail: tail));

    // 2) move mixer side (relies on .lag inside Ndef(\out) source)
    mixPos = (toSym == \A).if({ -1 }, { 1 });
    Ndef(\out).set(\mix_pos, mixPos);

    // 3) stop feeding old chain — no server.sync here
    Ndef(fromChainSym).set(oldGateKey, 0);

    // 4) schedule free of old chain after fade + tail
    ~jitFreeTask.notNil.if({ ~jitFreeTask.stop; ~jitFreeTask = nil; });
    ~jitFreeTask = AppClock.sched(fade + tail, {
        Ndef(fromOutSym).clear;
        Ndef(fromChainSym).clear;
        ~jitFreeTask = nil;
        nil
    });

    // State + notify
    ~jitActiveChain = toSym;
    ~jitCurrentSpec = ~jitNextSpec ?? { ~jitCurrentSpec };
    ~jitNextSpec = nil;
    ~jitOnRebuildNotify.(\didSwitch, (active: ~jitActiveChain, spec: ~jitCurrentSpec));
};

// Safe wrapper for CF build (uses inactive chain by default)
~jitBuildCF = { |spec|
    var inactive;
    (~jitCFEnabled.not).if({
        ~jitBuild.(spec);  // legacy single-chain build
    }, {
        ~jitOnRebuildNotify.(\willBuild, (spec: spec));
        ~jitNextSpec = spec;
        inactive = ~cfInactiveChain.(~jitActiveChain ? \A);
        (~jitBuildIntoChain ?? { |sp, ch| ("[WARN] ~jitBuildIntoChain missing").warn }).value(spec, inactive);
        ~jitOnRebuildNotify.(\didBuild, (inactive: inactive, spec: spec));
        ~jitStartCrossfadeTo.(inactive);
    });
};

// Alias for compatibility
~jitRebuildCrossfade = { |spec| ~jitBuildCF.(spec) };
)
