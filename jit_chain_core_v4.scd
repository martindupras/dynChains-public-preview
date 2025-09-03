// jit_chain_core_v4.scd
// MD 20250903 — JITLib chain runtime (build, playback, core helpers, v4)
// - Improvements vs v3:
//   * Unified validation helper
//   * Centralized downmix function (shared by Ndef out and pure chain maker)
//   * Optional destination safety limiter (off by default)
//   * ~jitBuild internally aligned with ~jitMakeChainFunc pipeline
//   * Clearer state init; resilient if utils didn’t load yet
//   * v4-identifying posts (no behavior change for setters / GUI)

(
/* =======================================================================
   Architecture
   - Load order (v4): jit_config_v4.scd -> jit_fxDefs_v4.scd -> jit_chain_core_v4.scd -> jit_chain_utils_v4.scd
   - Proxies:
       Ndef(\chain): multichannel processing graph (e.g., 6-ch)
       Ndef(\out):   terminal proxy; stereo downmix when needed or passthrough
   - Stage indexing:
       User-facing FX indices are 0..n-1 (first FX after \guitar is 0).
       NodeProxy.filter() slots are 1..n (slot 0 is the source).
   ======================================================================= */

// -------- v4 version tag + safe defaults --------
~jitChainCoreVersion = 4;

~jitFadeTime        = ~jitFadeTime        ? 0.25;
~numCh              = (~numCh ? 6).asInteger.max(1);
~sourceAmp          = ~sourceAmp          ? 0.7;
~defaultAmp         = ~defaultAmp         ? 0.8;
~jitUseRealInput    = (~jitUseRealInput   ? false) == true;
~jitUseSplayDownmix = (~jitUseSplayDownmix? true ) == true;

// Optional destination safety limiter (silent by default)
~jitUseLimiter      = ~jitUseLimiter      ? false;
~jitLimiterCeil     = ~jitLimiterCeil     ? 0.98;
~jitLimiterDur      = ~jitLimiterDur      ? 0.01;
~jitLimiterPostGain = ~jitLimiterPostGain ? 1.0;

// --------- Minimal state guards (in case utils aren’t loaded yet) ----------
~jitClearState = ~jitClearState ? {
    var dummy;
    // Reset bookkeeping used by utils and setters
    ~jitStageIndexNodes = Array.new;
    ~jitStageIdInfo     = IdentityDictionary.new;
};

// --------------- Shared helpers (v4) ---------------

// Normalize one stage entry to [symbol, argArray]
// - Accepts \fx or [\fx, (id: \foo, ...)] or [\fx, key, val, ...]
~jitNormalizeStage = { |entry|
    var sym, args, rest;
    sym = entry.isArray.if({ entry[0] }, { entry });
    args = [];
    if(entry.isArray and: { entry.size > 1 }) {
        rest = entry.copyRange(1, entry.size - 1);
        if(rest.size == 1 and: { rest[0].respondsTo(\keysValuesDo) }) {
            args = List.new;
            rest[0].keysValuesDo { |k, v| args.addAll([k, v]) };
            args = args.asArray;
        }{
            args = rest.flat;
        }
    };
    [sym, args]
};

// Split flat arg array into [id, dict]
~jitExtractIdAndDict = { |argsArray|
    var id, dict;
    id = nil;
    dict = IdentityDictionary.new;
    argsArray.clump(2).do { |kv|
        if(kv.size >= 2) {
            if(kv[0] == \id) { id = kv[1] } { dict[kv[0]] = kv[1] };
        }{
            ("[jit v4] Odd arg list; dropping trailing key %".format(kv[0])).warn;
        }
    };
    [id, dict]
};

// Name prefix for a stage given slot index and optional id
~jitStagePrefixFor = { |slot, id|
    var base;
    base = id.isNil.if({ "fx" ++ slot }, { id.asString });
    base
};

// Central spec validator (shared by builder and pure maker)
// Returns an Event: (ok: Bool, isStereoDest: Bool, stages: Array)
~jitValidateSpec = { |spec|
    var ok, last, stages, isStereoDest;

    ok = true;

    if(spec.isNil or: { spec.size < 2 }) {
        "[jit v4] Spec must be at least [\\guitar, \\destination].".warn; ok = false;
    };
    if(ok and: { spec.first != \guitar }) {
        "[jit v4] Spec must start with \\guitar.".warn; ok = false;
    };
    if(ok) {
        last = spec.last;
        isStereoDest = (last == \destinationStereo);
        if((last != \destination) and: { last != \destinationStereo }) {
            "[jit v4] Spec must end with \\destination or \\destinationStereo.".warn; ok = false;
        };
    };
    if(ok) {
        stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
        stages.do { |entry|
            var sym;
            sym = ~jitNormalizeStage.(entry)[0];
            if((~fxBuilders.isNil) or: { ~fxBuilders[sym].isNil }) {
                ("[jit v4] Unknown effect symbol: " ++ sym.asString).warn; ok = false;
            };
        };
    }{
        stages = [];
        isStereoDest = true;
    };

    (ok: ok, isStereoDest: isStereoDest, stages: stages)
};

// Downmix helper: array-or-scalar -> stereo array, optionally using Splay
~jitDownmixToStereo = { |inSig, useSplay = true|
    var arr, n, l, r, wL, wR;
    if(useSplay == true) {
        // If mono (scalar), duplicate; if array, Splay
        ^(inSig.isArray.if({ Splay.ar(inSig) }, { [inSig, inSig] }))
    };

    arr = inSig.isArray.if({ inSig }, { [inSig] });
    n = arr.size.max(1);

    // Manual weights (same as v3 defaults for 6-ch hex source)
    wL = Array.fill(n, 0.0);
    wR = Array.fill(n, 0.0);

    if(n > 0) { wL[0] = 1.0 };
    if(n > 1) { wR[1] = 1.0 };
    if(n > 2) { wL[2] = 0.5; wR[2] = 0.5 };
    if(n > 3) { wL[3] = 0.7 };
    if(n > 4) { wR[4] = 0.7 };
    if(n > 5) { wL[5] = 0.4; wR[5] = 0.4 };

    l = Mix.fill(n, { |i| arr[i] * wL[i] });
    r = Mix.fill(n, { |i| arr[i] * wR[i] });
    [l, r]
};

// Optional destination safety limiter (stereo or mono accepted)
~jitApplyLimiter = { |sig|
    var in, out;
    in = sig.isArray.if({ sig }, { [sig, sig] });  // accept mono
    out = Limiter.ar(in, ~jitLimiterCeil, ~jitLimiterDur) * (~jitLimiterPostGain ? 1.0);
    out
};

// ---------------- Pure maker: returns UGen func for the entire chain (v4) ----------------
~jitMakeChainFunc = { |spec|
    var v, ok, isStereoDest, stages;
    var makeSource, applyStages, makeDest;

    v = ~jitValidateSpec.(spec);
    ok = v[\ok];
    isStereoDest = v[\isStereoDest];
    stages = v[\stages];

    if(ok.not) {
        // Silent stereo function (safe for Ndef slots)
        ^{ Silent.ar(2) }
    };

    makeSource = {
        {
            var amp, sig, n;
            amp = NamedControl.kr(\src_amp, ~sourceAmp);
            n   = (~numCh ? 6).asInteger.max(1);
            sig = (~jitUseRealInput == true).if({
                SoundIn.ar( (0 .. (n - 1)) )
            },{
                WhiteNoise.ar(0.3) ! n
            });
            sig * amp
        }
    };

    applyStages = { |srcFunc|
        var func;
        func = {
            var sig;
            sig = srcFunc.value;
            stages.do { |entry, i|
                var sym, rawArgs, id, argsDict, prefix, builder, filterFunc;
                # sym, rawArgs = ~jitNormalizeStage.(entry);
                # id,  argsDict = ~jitExtractIdAndDict.(rawArgs);
                prefix     = ~jitStagePrefixFor.(i, id);
                builder    = ~fxBuilders[sym];
                filterFunc = builder.(prefix, argsDict);    // returns { |in| ... }
                sig = filterFunc.(sig);
            };
            sig
        };
        func
    };

    makeDest = { |sigFunc|
        var mustStereoLocal;
        mustStereoLocal = isStereoDest or: { s.options.numOutputBusChannels <= 2 };
        {
            var amp, in, outSig;
            amp = NamedControl.kr(\dest_amp, ~defaultAmp);
            in  = sigFunc.value;

            outSig = mustStereoLocal.if({
                ~jitDownmixToStereo.(in, ~jitUseSplayDownmix)
            },{
                // multichannel pass-through (no downmix)
                in
            });

            if(~jitUseLimiter == true) {
                outSig = ~jitApplyLimiter.(outSig);
            };

            outSig * amp
        }
    };

    // Compose
    {
        var srcF, fxF, outF;
        srcF = makeSource.value;
        fxF  = applyStages.(srcF);
        outF = makeDest.(fxF);
        outF.value
    }
};

// ---------------- Build (or rebuild) the chain (v4) ----------------
// spec: [\guitar, [\tremolo, (id:\t1, rate:3)], ..., \destination or \destinationStereo]
~jitBuild = { |spec|
    var v, ok, isStereoDest, stages, nInChannels, mustStereo;

    // Validate once
    v = ~jitValidateSpec.(spec);
    ok = v[\ok];
    isStereoDest = v[\isStereoDest];
    stages = v[\stages];

    if(ok.not) { ^nil };  // abort without side effects

    // Prepare proxies
    Ndef(\chain).fadeTime = ~jitFadeTime;
    Ndef(\out).fadeTime   = ~jitFadeTime;

    Ndef(\chain).clear;

    // Source (demo or real input)
    Ndef(\chain).source = {
        var amp, sig, n;
        amp = NamedControl.kr(\src_amp, ~sourceAmp);
        n   = (~numCh ? 6).asInteger.max(1);
        sig = (~jitUseRealInput == true).if({
            SoundIn.ar( (0 .. (n - 1)) )
        },{
            WhiteNoise.ar(0.3) ! n
        });
        sig * amp
    };

    // Reset bookkeeping (language-side)
    ~jitClearState.();
    ~jitBypass = (~jitBypass ? false);

    // Add filters on \chain (filters are 1-based; source is slot 0)
    if(~jitBypass == false) {
        stages.do { |entry, i|
            var sym, rawArgs, id, argsDict, prefix, builder, filterFunc;
            # sym, rawArgs = ~jitNormalizeStage.(entry);
            # id,  argsDict = ~jitExtractIdAndDict.(rawArgs);

            prefix     = ~jitStagePrefixFor.(i, id);
            builder    = ~fxBuilders[sym];
            filterFunc = builder.(prefix, argsDict); // { |in| ... }

            Ndef(\chain).filter(i + 1, filterFunc);

            ~jitStageIndexNodes = ~jitStageIndexNodes.add(prefix.asSymbol);
            if(id.notNil) { ~jitStageIdInfo[id] = (slot: i, prefix: prefix.asString) };
        };
    }{
        "[jit v4] Bypassing stages (~jitBypass == true)".postln;
    };

    // Output proxy \out (downmix or pass-through)
    mustStereo = isStereoDest or: { s.options.numOutputBusChannels <= 2 };

    // Determine current input channels (fallback to ~numCh)
    nInChannels = (Ndef(\chain).numChannels ? ~numCh).max(1);

    Ndef(\out).clear;
    Ndef(\out).source = {
        var amp, in, outSig;
        amp = NamedControl.kr(\dest_amp, ~defaultAmp);
        in  = Ndef(\chain).ar;  // follow actual channel count

        outSig = mustStereo.if({
            ~jitDownmixToStereo.(in, ~jitUseSplayDownmix)
        },{
            in
        });

        if(~jitUseLimiter == true) {
            outSig = ~jitApplyLimiter.(outSig);
        };

        outSig * amp
    };

    ("[jit v4] Ndef(\\chain) chans: " ++ Ndef(\chain).numChannels
        ++ " | Ndef(\\out) chans: " ++ Ndef(\out).numChannels).postln;

    ~jitCurrentSpec = spec.copy;
    spec
};

// ---------------- Play / Free (v4) ----------------
~jitPlay = {
    var dummy;
    Ndef(\out).play(~outOffset);
};

~jitFree = {
    var dummy;
    Ndef(\out).stop;   Ndef(\out).clear;
    Ndef(\chain).stop; Ndef(\chain).clear;
    ~jitClearState.();
};

// ---------------- Per-slot builder for CF side (A or B) ----------------
~jitBuildIntoChain = { |which, spec|
    var func;
    func = ~jitMakeChainFunc.(spec);
    func
};

// ---------------- Cmd-. hook (idempotent) ----------------
~jitFreeHook = (~jitFreeHook ? { { ~jitFree.value }.forkIfNeeded; });
CmdPeriod.remove(~jitFreeHook);
CmdPeriod.add(~jitFreeHook);

)
