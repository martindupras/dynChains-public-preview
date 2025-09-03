// jit_chain_crossfade_v2.scd
(
// ── Configuration defaults (respects your style)
~jitCFEnabled = ~jitCFEnabled ?? { false };
~jitCF = ~jitCF ?? { (fadeTime: (~jitFadeTime ? 0.25), tailHold: 2.0) };
~jitActiveChain = ~jitActiveChain ?? { \A };
~jitNextSpec = nil;
~jitFreeTask = nil;
~jitListeners = ~jitListeners ?? { Array.new };

// ── Utilities
~jitOnRebuildNotify = ~jitOnRebuildNotify ?? { |phase, payload|
    ~jitListeners.do { |fn| fn.value(phase, payload) };
};

~jitEnsureCFNdefs = ~jitEnsureCFNdefs ?? {
    Ndef(\out).source = {
        var a, b, mix_pos, sig, mix_lag;
        a = Ndef(\outA).ar(2);
        b = Ndef(\outB).ar(2);
        mix_pos = NamedControl.kr(\mix_pos, (~jitActiveChain == \A).if({ -1 }, { 1 }));
        mix_lag = ~jitCF.fadeTime;
        sig = XFade2.ar(a, b, mix_pos.lag(mix_lag));
        sig;
    };
    Ndef(\out).fadeTime = ~jitFadeTime ? 0.25;
};

~jitBuildIntoChain = ~jitBuildIntoChain ?? { |spec, chainSym = \A|
    var chainName, outName, gateName, useSplay, localFade;
    var chainFunc, outFunc;
    chainName = (("chain" ++ chainSym.asString).asSymbol);
    outName = (("out" ++ chainSym.asString).asSymbol);
    gateName = (("chain" ++ chainSym.asString ++ "_gate").asSymbol);
    useSplay = ~jitUseSplayDownmix ? true;
    localFade = ~jitFadeTime ? 0.25;

    chainFunc = {
        var chgate, src, sig;
        chgate = NamedControl.kr(gateName, 1).lag(~jitCF.fadeTime);
        src = Ndef(\src).ar; // multichannel from your session
        sig = src * chgate;

        // Fallback stage application using ~fxBuilders; replace with your normalizer if present
        sig = (~jitApplyStages ?? { |inSig, stages|
            var outSig;
            outSig = inSig;
            stages.do { |st|
                var name, fxb;
                name = (st[\fx] ? st ? st.asSymbol);
                fxb = (~fxBuilders ? IdentityDictionary.new)[name];
                (fxb.notNil).if({
                    outSig = fxb.value(outSig, st);
                }, {
                    outSig = outSig;
                });
            };
            outSig;
        }).value(sig, (~jitNormalizeSpec ?? { |x| x }).value(spec));

        sig;
    };

    Ndef(chainName).source = chainFunc;
    Ndef(chainName).fadeTime = localFade;

    outFunc = {
        var inSig, stereo;
        inSig = Ndef(chainName).ar;
        stereo = useSplay.if({
            Splay.ar(inSig, spread: 1.0, level: 1.0);
        }, {
            var m;
            m = Mix.new(inSig);
            [m, m];
        });
        stereo;
    };

    Ndef(outName).source = outFunc;
    Ndef(outName).fadeTime = localFade;
};

~jitStartCrossfadeTo = ~jitStartCrossfadeTo ?? { |targetSym|
    var fromSym, toSym, oldGate, fade, tail;
    fromSym = ~jitActiveChain;
    toSym = targetSym;
    fade = ~jitCF.fadeTime;
    tail = ~jitCF.tailHold;
    oldGate = (("chain" ++ fromSym.asString ++ "_gate").asSymbol);

    ~jitOnRebuildNotify.(\willSwitch, (from: fromSym, to: toSym, fade: fade, tail: tail));
    ~jitEnsureCFNdefs.();
    Ndef(\out).set(\mix_pos, (toSym == \A).if({ -1 }, { 1 }));
    Ndef(\out).server.sync;
    Ndef(("chain" ++ fromSym.asString).asSymbol).set(oldGate, 0);

    ~jitFreeTask.notNil.if({ ~jitFreeTask.stop; ~jitFreeTask = nil; });
    ~jitFreeTask = AppClock.sched(fade + tail, {
        Ndef(("out" ++ fromSym.asString).asSymbol).clear;
        Ndef(("chain" ++ fromSym.asString).asSymbol).clear;
        ~jitFreeTask = nil;
        nil;
    });

    ~jitActiveChain = toSym;
    ~jitCurrentSpec = ~jitNextSpec ?? { ~jitCurrentSpec };
    ~jitNextSpec = nil;
    ~jitOnRebuildNotify.(\didSwitch, (active: ~jitActiveChain, spec: ~jitCurrentSpec));
};

// ── Public API glue
~jitSetCrossfade = { |fade = 0.25, tail = 2.0|
    ~jitCF = (fadeTime: fade, tailHold: tail);
    ~jitCFEnabled = true;
    ~jitEnsureCFNdefs.();
};

~jitEnableCrossfade = { |bool = true|
    ~jitCFEnabled = bool;
    bool.if({ ~jitEnsureCFNdefs.() });
};

~jitBuildCF = { |spec|
    var inactive;
    (~jitCFEnabled.not).if({
        ~jitBuild.(spec);
    }, {
        ~jitOnRebuildNotify.(\willBuild, (spec: spec));
        ~jitNextSpec = spec;
        inactive = (~jitActiveChain == \A).if({ \B }, { \A });
        ~jitBuildIntoChain.(spec, inactive);
        ~jitOnRebuildNotify.(\didBuild, (inactive: inactive, spec: spec));
        ~jitStartCrossfadeTo.(inactive);
    });
};
~jitRebuildCrossfade = { |spec| ~jitBuildCF.(spec) };

// ── Wrap legacy ~jitBuild without modifying original source
~jitBuild = {
    var orig = ~jitBuild;
    { |spec|
        (~jitCFEnabled).if({
            ~jitBuildCF.(spec);
        }, {
            orig.value(spec);
        });
    };
}.value;

// ── Make ~jitFree CF-aware without breaking callers
~jitFree = {
    var orig = ~jitFree;
    {
        ~jitFreeTask.notNil.if({ ~jitFreeTask.stop; ~jitFreeTask = nil; });
        [\A, \B].do { |sym|
            Ndef(("out" ++ sym.asString).asSymbol).clear(0.0);
            Ndef(("chain" ++ sym.asString).asSymbol).clear(0.0);
        };
        Ndef(\out).clear(0.0);
        Ndef(\chain).clear(0.0);
        orig.notNil.if({ orig.value });
    }.value;
};

/*~jitStatus = {
    var orig = ~jitStatus;
    {
        var a = ~jitActiveChain;
        var fade = ~jitCF.fadeTime;
        var tail = ~jitCF.tailHold;
        ("jit v2 status — CF:%  active:%  fade:%  tail:%").format(~jitCFEnabled, a, fade, tail).postln;
        (~jitNextSpec.notNil).if({ " nextSpec present (transition)".postln; });
        orig.notNil.if({ orig.value });
    }.value;
};*/
)
