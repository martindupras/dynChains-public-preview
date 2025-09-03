// jit_chain_crossfade_v6.scd
// Clean v6 crossfade engine: debounce builds, robust switch ordering, adapter mapping, maintainable split for v6 architecture.

(
    // =========================
    // Global CF state (v6)
    // =========================
    ~jitCF = ~jitCF ? IdentityDictionary.new;
    ~jitCF[\fadeTime] = ~jitCF[\fadeTime] ? 0.08;
    ~jitCF[\tailHold] = ~jitCF[\tailHold] ? 0.25;

    ~jitCFActiveSide = ~jitCFActiveSide ? \A;       // Current active side (\A or \B)
    ~jitCFFadeTime   = ~jitCFFadeTime   ? ~jitCF[\fadeTime];
    ~jitCFTailTime   = ~jitCFTailTime   ? ~jitCF[\tailHold];

    ~jitCFDebounceSec = ~jitCFDebounceSec ? 0.08;   // debounce rapid builds
    ~jitCFBuildLatest = ~jitCFBuildLatest ? IdentityDictionary.new;
    ~jitCFDebounceRunning = ~jitCFDebounceRunning ? IdentityDictionary.new;
    ~jitCFBuildPending = ~jitCFBuildPending ? IdentityDictionary.new;
    ~jitCFGates = ~jitCFGates ? IdentityDictionary.new;
    ~jitCFStopToken = ~jitCFStopToken ? IdentityDictionary.new;
    ~jitCFStopTokenCounter = ~jitCFStopTokenCounter ? 0;
    ~jitXFadeInstalled = ~jitXFadeInstalled ? false;

    // =========================
    // Helpers
    // =========================

    // Side (\A or \B) -> proxy symbol
    ~jit_CF_sideToProxy = { |side| if(side == \A) { \outA } { \outB } };

    // Spec validator: uses user's validator if present, else minimal
    ~jitCF_isValidSpec = { |spec|
        if(~jitIsValidSpec.notNil) { ~jitIsValidSpec.(spec) } {
            var last;
            spec.notNil and: { spec.isArray } and: { spec.size >= 2 }
            and: {
                last = spec.last;
                (last == \destination) or: { last == \destinationStereo }
            }
        }
    };

    // =========================
    // Mixer install / keep-alive
    // =========================

    ~jitSetCrossfade = { |fade = 0.08, tail = 0.25|
        var active, initMix;
        ~jitCFFadeTime = fade;
        ~jitCFTailTime = tail;
        ~jitCF[\fadeTime] = fade;
        ~jitCF[\tailHold] = tail;
        Ndef(\out).source = {
            var a, b, pos;
            a = Ndef.ar(\outA);
            b = Ndef.ar(\outB);
            pos = VarLag.kr(\mix_pos.kr(-1), \mix_lag.kr(fade));
            XFade2.ar(a, b, pos)
        };
        Ndef(\outA).fadeTime = 0.0;
        Ndef(\outB).fadeTime = 0.0;
        ~jitXFadeInstalled = true;
        active = ~jitCFActiveSide ? \A;
        initMix = if(active == \A) { -1 } { 1 };
        Ndef(\out).set(\mix_pos, initMix, \mix_lag, fade);
    };

    ~jitCFEnsureMixer = {
        var needs;
        needs = Ndef(\out).source.isNil or: { ~jitXFadeInstalled.not };
        if(needs) { ~jitSetCrossfade.(~jitCFFadeTime ? 0.08, ~jitCFTailTime ? 0.25) };
    };

    // =========================
    // Debounced inactive-side build
    // =========================

    ~jitBuildCF = { |side, spec|
        var sideSym, proxy, isSame;
        sideSym = ~jit_CF_sideToProxy.(side);
        proxy = Ndef(sideSym);
        if(~jitCF_isValidSpec.(spec).not) { ^nil };
        isSame = ((~jitCFBuildLatest[sideSym] == spec) and: { proxy.source.notNil });
        if(isSame.not) {
            ~jitCFBuildLatest[sideSym] = spec;
            if(~jitCFDebounceRunning[sideSym] ? false) {
                // already scheduled, latest will be used
            }{
                ~jitCFDebounceRunning[sideSym] = true;
                ~jitCFBuildPending[sideSym] = true;
                AppClock.sched(~jitCFDebounceSec, {
                    var s, f;
                    s = ~jitCFBuildLatest[sideSym];
                    f = ~jitMakeChainFunc.notNil.if({ ~jitMakeChainFunc.(s) }, { nil });
                    if(f.notNil) {
                        proxy.source = f;
                        proxy.play;
                        proxy.set(\gate, 1);
                        ~jitCFGates[sideSym] = 1;
                    };
                    ~jitCFDebounceRunning[sideSym] = false;
                    ~jitCFBuildPending[sideSym] = false;
                    nil
                });
            }
        }
    };

    // =========================
    // Preview into the inactive side
    // =========================

    ~jitCFPreview = { |spec|
        var curSide, side;
        if(~jitCF_isValidSpec.(spec).not) { ^nil };
        curSide = ~jitCFActiveSide ? \A;
        side = if(curSide == \A) { \B } { \A };
        if((~jitNextSpec == spec).not) {
            ~jitNextSpec = spec;
            { if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() } }.defer;
            { ~jitBuildCF.(side, spec) }.defer;
        }
    };

    // =========================
    // Start crossfade to target
    // =========================

    ~jitStartCrossfadeTo = { |toSide, fade, tail|
        var toSym, fromSide, fromSym, toProxy, fromProxy, f, t, mixTo, token;
        f = fade ? (~jitCFFadeTime ? 0.08);
        t = tail ? (~jitCFTailTime ? 0.25);

        ~jitCFEnsureMixer.();

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
            nil
        });

        ~jitCFStopTokenCounter = (~jitCFStopTokenCounter ? 0) + 1;
        token = ~jitCFStopTokenCounter;
        ~jitCFStopToken[fromSym] = token;

        AppClock.sched(f + t, {
            var stillValid, pending;
            stillValid = (~jitCFStopToken[fromSym] == token);
            pending = ~jitCFBuildPending[fromSym] ? false;
            if(stillValid and: { pending.not }) { fromProxy.stop };
            nil
        });
    };

    // =========================
    // Immediate / scheduled switch
    // =========================

    ~jitCFSwitchNow = { |fade = nil, tail = nil|
        var newSpec, f, t, targetSide;
        newSpec = ~jitNextSpec ? ~jitCurrentSpec;
        if(~jitCF_isValidSpec.(newSpec)) {
            f = fade ? (~jitCFFadeTime ? 0.08);
            t = tail ? (~jitCFTailTime ? 0.25);
            ~jitCurrentSpec = newSpec;
            ~jitNextSpec = nil;
            if(~jitNotifyWillSwitch.notNil) { ~jitNotifyWillSwitch.(newSpec) };
            targetSide = if((~jitCFActiveSide ? \A) == \A) { \B } { \A };
            ~jitStartCrossfadeTo.(targetSide, f, t);
            {
                if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
                if(~jitNotifyDidSwitch.notNil) { ~jitNotifyDidSwitch.(newSpec) };
            }.defer;
        }
    };

    ~jitCFSwitchIn = { |sec = 0.5, fade = nil, tail = nil|
        var t, f, tl;
        t = sec.max(0.0);
        f = fade ? (~jitCFFadeTime ? 0.08);
        tl = tail ? (~jitCFTailTime ? 0.25);
        AppClock.sched(t, { ~jitCFSwitchNow.(f, tl); nil });
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