// jit_chain_core_v6.scd
// JITLib chain runtime (build, playback, core helpers) — Refactored for clarity, robustness, and future extensibility.

(
    /* =======================================================================
       Architecture
       - Load order: jit_config_v6.scd -> jit_fxDefs_v6.scd -> jit_chain_core_v6.scd -> jit_chain_utils_v6.scd
       - Proxies:
           Ndef(\chain): multichannel processing graph (e.g., 6-ch)
           Ndef(\out):   terminal proxy; stereo downmix when needed or passthrough
       - Stage indexing:
           User-facing FX indices are 0..n-1 (first FX after \guitar is 0).
           NodeProxy.filter() slots are 1..n (slot 0 is the source).
       ======================================================================= */

    // ---- Helper: Normalize a chain stage entry ----
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

    // ---- Helper: Extract id and dictionary from flat args array ----
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

    // ---- Helper: Build prefix string for each stage ----
    ~jitStagePrefixFor = { |slot, id|
        var base = id.isNil.if({ "fx" ++ slot }, { id.asString });
        base
    };


// ---- Source helpers (BlackHole <-> Test) ----

// Hex test generator: returns a multichannel Array of UGens (no amps baked in)
~hexTestSig = { |numChIn|
    var numCh, freqs, centsJitter, vibrato, sig, perChAmp;
    numCh = (numChIn ? (~numCh ? 6)).asInteger.max(1);

    // E2 A2 D3 G3 B3 E4 (extend/shrink as needed)
    freqs = [82.41, 110, 146.83, 196, 246.94, 329.63];
    (numCh < freqs.size).if({
        freqs = freqs.copyRange(0, numCh - 1);
    },{
        (numCh > freqs.size).if({
            freqs = freqs ++ Array.fill(numCh - freqs.size, { |i| freqs.last * (2 ** (i + 1)) });
        });
    });

    centsJitter = LFNoise2.kr(0.25 ! numCh).range(-4, 4);  // slow ±4 cents
    vibrato     = SinOsc.kr(5 ! numCh, 0, 0.003, 1);       // subtle vibrato ratio
    perChAmp    = 0.12;                                    // conservative; global amp handled outside
    sig = Array.fill(numCh, { |i|
        var f      = freqs[i] * (2 ** (centsJitter[i] / 1200)) * vibrato[i];
        var tone   = Mix([ Saw.ar(f), Pulse.ar(f * 2, 0.4) ]) * 0.5; // soft blend
        var gate   = LFPulse.kr(0.2 + (0.05 * i), 0, 0.2).lag(0.03); // gentle motion per string
        var shape  = (0.15 + (0.2 * gate));
        tone * shape * perChAmp
    });

    sig
};

// Returns the chosen source signal (Array of UGens or multichannel UGen)
// Priority: ~sourceMode (\blackhole | \test) if set; otherwise ~jitUseRealInput boolean
~jitSelectSourceSig = { |numChIn|
    var numCh, mode, sig, idx;
    numCh = (numChIn ? (~numCh ? 6)).asInteger.max(1);

    // Build [0, 1, ..., numCh-1] safely (avoids the '..' parse issue)
    idx = Array.series(numCh, 0, 1);

    mode = (~sourceMode ? ((~jitUseRealInput == true).if(\blackhole, \test)));

    sig = (mode == \blackhole).if({
        SoundIn.ar(idx)          // multichannel input from device (e.g. BlackHole)
    },{
        ~hexTestSig.(numCh)      // multichannel hex test generator
    });

    sig
};



    // ---- Chain Builder: Build (or rebuild) the chain ----
    // spec: [\guitar, [\tremolo, (id:\t1, rate:3)], ..., \destination or \destinationStereo]
    ~jitBuild = { |spec|
        var ok = true, last, stages, isStereoDest, mustStereo, nInChannels;

        // ---- Validate spec ----
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
                var sym = ~jitNormalizeStage.(entry)[0];
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
            var amp = NamedControl.kr(\src_amp, ~sourceAmp);
            var sig = (~jitUseRealInput == true).if({
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
		var amp, in, l, r;
            amp = NamedControl.kr(\dest_amp, ~defaultAmp);
            in  = Ndef(\chain).ar;  // follow actual channel count

            mustStereo.if({
                (~jitUseSplayDownmix == true).if({
                    Splay.ar(in) * amp
                },{
                    var wL = Array.fill(nInChannels, 0.0);
                    var wR = Array.fill(nInChannels, 0.0);

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
        var ok = true, last, stages, isStereoDest, mustStereo, nInGuess, srcAmpDefault, destAmpDefault;
        var validate, makeSource, applyStages, makeDest;

        srcAmpDefault  = ~sourceAmp ? 0.7;
        destAmpDefault = ~defaultAmp ? 0.8;

        // ---- Validation ----
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
                    var sym = ~jitNormalizeStage.(entry)[0];
                    ((~fxBuilders.isNil) or: { ~fxBuilders[sym].isNil }).if({
                        ("Unknown effect symbol: " ++ sym.asString).warn; ok = false;
                    });
                };
            });
        };

        makeSource = {
            {
                var amp = NamedControl.kr(\src_amp, srcAmpDefault);
                var sig = (~jitUseRealInput == true).if({
                    SoundIn.ar( (0 .. ((~numCh ? 2) - 1)) )
                },{
                    WhiteNoise.ar(0.3) ! (~numCh ? 2)
                });
                sig * amp
            }
        };

        applyStages = { |srcFunc|
            {
                var sig = srcFunc.value;
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
            }
        };

        makeDest = { |sigFunc|
            var mustStereoLocal = isStereoDest or: { s.options.numOutputBusChannels <= 2 };
            {
                var amp = NamedControl.kr(\dest_amp, destAmpDefault);
                var in  = sigFunc.value;

                // determine channel count from the built graph or fallback guess
                var nInChannels = (in.isArray).if({ in.size }, { ~numCh ? 2 }).max(1);

                mustStereoLocal.if({
                    (~jitUseSplayDownmix == true).if({
                        (in.isArray.not).if({ [in, in] * amp }, { Splay.ar(in) * amp })
                    },{
					var wL, wR, l, r;
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
            var srcF = makeSource.value;
            var fxF  = applyStages.(srcF);
            var outF = makeDest.(fxF);
            outF
        })
    };

    // --- Per-slot builder: return the UGen function for CF side (A or B) ---
    ~jitBuildIntoChain = { |which, spec|
        var func = ~jitMakeChainFunc.(spec);
        func
    };

    // ---- Cmd-. hook (idempotent) ----
    ~jitFreeHook = (~jitFreeHook ? { { ~jitFree.value }.forkIfNeeded; });
    CmdPeriod.remove(~jitFreeHook);
    CmdPeriod.add(~jitFreeHook);
)