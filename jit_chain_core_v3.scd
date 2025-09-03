// jit_chain_core_v3.scd
// MD 20250902 — JITLib chain runtime (build, playback, core helpers)

(
/* =======================================================================
   Architecture
   - Load order: jit_config_v3.scd -> jit_fxDefs_v3.scd -> jit_chain_core_v3.scd -> jit_chain_utils_v3.scd
   - Proxies:
       Ndef(\chain): multichannel processing graph (e.g., 6-ch)
       Ndef(\out):   terminal proxy; stereo downmix when needed or passthrough
   - Stage indexing:
       User-facing FX indices are 0..n-1 (first FX after \guitar is 0).
       NodeProxy.filter() slots are 1..n (slot 0 is the source).
   ======================================================================= */

// ---- Minimal helpers the builder needs ----
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

~jitExtractIdAndDict = { |argsArray|
    var id, dict;
    id = nil;
    dict = IdentityDictionary.new;
    argsArray.clump(2).do { |kv|
        if(kv.size >= 2) {
            if(kv[0] == \id) { id = kv[1] } { dict[kv[0]] = kv[1] };
        }{
            ("Odd arg list; dropping trailing key %".format(kv[0])).warn;
        }
    };
    [id, dict]
};

~jitStagePrefixFor = { |slot, id|
    var base;
    base = id.isNil.if({ "fx" ++ slot }, { id.asString });
    base
};

// ---- Build (or rebuild) the chain ----
// spec: [\guitar, [\tremolo, (id:\t1, rate:3)], ..., \destination or \destinationStereo]
~jitBuild = { |spec|
    var ok, last, stages, isStereoDest, mustStereo, nInChannels;

    ok = true;

    // ---- Validate spec (caret-free) ----
    (spec.isNil or: { spec.size < 2 }).if({
        "Spec must be at least [\\guitar, \\destination].".warn; ok = false;
    });
    ok.if({
        (spec.first != \guitar).if({
            "Spec must start with \\guitar.".warn; ok = false;
        });
    });
    ok.if({
        last = spec.last;
        isStereoDest = (last == \destinationStereo);
        ((last != \destination) and: { last != \destinationStereo }).if({
            "Spec must end with \\destination or \\destinationStereo.".warn; ok = false;
        });
    });
    ok.if({
        stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
        stages.do { |entry|
            var sym;
            sym = ~jitNormalizeStage.(entry)[0];
            ((~fxBuilders.isNil) or: { ~fxBuilders[sym].isNil }).if({
                ("Unknown effect symbol: " ++ sym.asString).warn; ok = false;
            });
        };
    });

    // Abort if spec invalid
    ok.if({}, { nil });

    // ---- Prepare proxies ----
    Ndef(\chain).fadeTime = ~jitFadeTime;
    Ndef(\chain).clear;

    // -------- Source (demo or real input) --------
    Ndef(\chain).source = {
        var amp, sig;
        amp = NamedControl.kr(\src_amp, ~sourceAmp);

        sig = (~jitUseRealInput == true).if({
            SoundIn.ar( (0 .. (~numCh - 1)) )
        },{
            WhiteNoise.ar(0.3) ! ~numCh
        });

        sig * amp
    };

    // Reset registry (language-side bookkeeping)
    ~jitClearState.();
    ~jitBypass = (~jitBypass ? false);  // optional dev bypass switch

    // -------- Add filters on \chain (filters are 1-based; source is slot 0) --------
    (~jitBypass == false).if({
        stages.do { |entry, i|
            var sym, rawArgs, id, argsDict, prefix, builder, filterFunc;
            # sym, rawArgs = ~jitNormalizeStage.(entry);
            # id,  argsDict = ~jitExtractIdAndDict.(rawArgs);
            prefix     = ~jitStagePrefixFor.(i, id);
            builder    = ~fxBuilders[sym];
            filterFunc = builder.(prefix, argsDict);

            Ndef(\chain).filter(i + 1, filterFunc);

            ~jitStageIndexNodes = ~jitStageIndexNodes.add(prefix.asSymbol);
            if(id.notNil) { ~jitStageIdInfo[id] = (slot: i, prefix: prefix.asString) };
        };
    },{
        "Bypassing stages (~jitBypass == true)".postln;
    });

    // ---- Output proxy \out (safe downmix when needed) ----
    mustStereo = isStereoDest or: { s.options.numOutputBusChannels <= 2 };
    Ndef(\out).fadeTime = ~jitFadeTime;

    // Determine input channel count (proxy knows it once source+filters are set)
    nInChannels = (Ndef(\chain).numChannels ? ~numCh).max(1);

    Ndef(\out).source = {
        var amp, in, l, r, wL, wR;
        amp = NamedControl.kr(\dest_amp, ~defaultAmp);
        in  = Ndef(\chain).ar;  // follow actual channel count

        mustStereo.if({
            (~jitUseSplayDownmix == true).if({
                Splay.ar(in) * amp
            },{
                wL = Array.fill(nInChannels, 0.0);
                wR = Array.fill(nInChannels, 0.0);

                if(nInChannels > 0) { wL[0] = 1.0 };
                if(nInChannels > 1) { wR[1] = 1.0 };
                if(nInChannels > 2) { wL[2] = 0.5; wR[2] = 0.5 };
                if(nInChannels > 3) { wL[3] = 0.7 };
                if(nInChannels > 4) { wR[4] = 0.7 };
                if(nInChannels > 5) { wL[5] = 0.4; wR[5] = 0.4 };

                l = Mix.fill(nInChannels, { |i| in[i] * wL[i] });
                r = Mix.fill(nInChannels, { |i| in[i] * wR[i] });
                [l, r] * amp
            })
        },{
            in * amp // multichannel pass-through
        })
    };

    // Confirmation
    ("Ndef(\\chain) channels: " ++ Ndef(\chain).numChannels
        ++ " | Ndef(\\out) channels: " ++ Ndef(\out).numChannels).postln;

    ~jitCurrentSpec = spec.copy;
    spec
};

// ---- Play / Free ----
~jitPlay = {
    // Play the OUTPUT proxy, not the chain
    Ndef(\out).play(~outOffset);
};

~jitFree = {
    // Stop and clear both proxies
    Ndef(\out).stop;   Ndef(\out).clear;
    Ndef(\chain).stop; Ndef(\chain).clear;
    ~jitClearState.();
};

// --- Pure maker: returns a UGen function for the entire chain (no side effects) ---
~jitMakeChainFunc = ~jitMakeChainFunc ? { |spec|
    var ok, last, stages, isStereoDest, mustStereo, nInGuess, srcAmpDefault, destAmpDefault;
    var validate, makeSource, applyStages, makeDest;

    ok = true;
    srcAmpDefault  = ~sourceAmp ? 0.7;
    destAmpDefault = ~defaultAmp ? 0.8;

    // ---- Validation (caret-free) ----
    validate = {
        (spec.isNil or: { spec.size < 2 }).if({
            "Spec must be at least [\\guitar, \\destination].".warn; ok = false;
        });
        ok.if({
            (spec.first != \guitar).if({
                "Spec must start with \\guitar.".warn; ok = false;
            });
        });
        ok.if({
            last = spec.last;
            isStereoDest = (last == \destinationStereo);
            ((last != \destination) and: { last != \destinationStereo }).if({
                "Spec must end with \\destination or \\destinationStereo.".warn; ok = false;
            });
        });
        ok.if({
            stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
            stages.do { |entry|
                var sym;
                sym = ~jitNormalizeStage.(entry)[0];
                ((~fxBuilders.isNil) or: { ~fxBuilders[sym].isNil }).if({
                    ("Unknown effect symbol: " ++ sym.asString).warn; ok = false;
                });
            };
        });
    };

    makeSource = {
        {
            var amp, sig;
            amp = NamedControl.kr(\src_amp, srcAmpDefault);
            sig = (~jitUseRealInput == true).if({
                SoundIn.ar( (0 .. ((~numCh ? 2) - 1)) )
            },{
                WhiteNoise.ar(0.3) ! (~numCh ? 2)
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
            var amp, in, l, r, wL, wR, nInChannels;
            amp = NamedControl.kr(\dest_amp, destAmpDefault);
            in  = sigFunc.value;

            // determine channel count from the built graph or fallback guess
            nInChannels = (in.isArray).if({ in.size }, { ~numCh ? 2 }).max(1);

            mustStereoLocal.if({
                (~jitUseSplayDownmix == true).if({
                    (in.isArray.not).if({ [in, in] * amp }, { Splay.ar(in) * amp })
                },{
                    // Manual downmix with simple weights
                    wL = Array.fill(nInChannels, 0.0);
                    wR = Array.fill(nInChannels, 0.0);

                    if(nInChannels > 0) { wL[0] = 1.0 };
                    if(nInChannels > 1) { wR[1] = 1.0 };
                    if(nInChannels > 2) { wL[2] = 0.5; wR[2] = 0.5 };
                    if(nInChannels > 3) { wL[3] = 0.7 };
                    if(nInChannels > 4) { wR[4] = 0.7 };
                    if(nInChannels > 5) { wL[5] = 0.4; wR[5] = 0.4 };

                    l = Mix.fill(nInChannels, { |i| (in.isArray.if({ in[i] }, { in })) * wL[i] });
                    r = Mix.fill(nInChannels, { |i| (in.isArray.if({ in[i] }, { in })) * wR[i] });
                    [l, r] * amp
                })
            },{
                in * amp // multichannel pass-through
            })
        }
    };

    // Run validation
    validate.value;

    // If invalid, return a silent 2ch function (safe in Ndef slots)
    ok.not.if({
        { Silent.ar(2) }
    },{
        // Compose source -> stages -> destination
        var srcF, fxF, outF;
        srcF = makeSource.value;
        fxF  = applyStages.(srcF);
        outF = makeDest.(fxF);
        outF
    })
};

// --- Per-slot builder: return the UGen function for CF side (A or B) ---
~jitBuildIntoChain = { |which, spec|
    var func;
    func = ~jitMakeChainFunc.(spec);
    func
};

// // in jit_chain_core_v3.scd (additive, no behavior changes elsewhere)
// ~jitBuildIntoChain = ~jitBuildIntoChain ? { |which, spec|
// 	var func;
// 	// Produce a UGen *function* for the spec without binding it to Ndef(\out).
// 	// For example: func = ~jitMakeChainFunc.(spec);
// 	// If no such maker exists yet, return Silent.ar to avoid breaking.
// 	func ? { Silent.ar(2) }
// };


// ---- Cmd-. hook (idempotent) ----
~jitFreeHook = (~jitFreeHook ? { { ~jitFree.value }.forkIfNeeded; });
CmdPeriod.remove(~jitFreeHook);
CmdPeriod.add(~jitFreeHook);
)
