// jit_fxDefs_v6.scd
// Session-wide FX builders for JITLib signal chains.
// Refactored for clarity, robustness, and future extensibility.

(
    // --- FX builder registry ---
    ~fxBuilders = IdentityDictionary.new;

    // --- Helper: Coerce nil to empty Event ---
    // Ensures .at(\key) ? default pattern is always safe
    ~argsOrEvent = { |args| args ? () };

    // ------------------------------------------------------------
    // Tremolo
    // rate:  (Hz)      -- LFO rate
    // depth: (0..1)    -- Amount of tremolo
    // phase: (0..1)    -- Phase offset (fraction of 2pi)
    // ------------------------------------------------------------
    ~fxBuilders[\tremolo] = { |prefix, args = nil|
	var a, rateCtl, depthCtl, phaseCtl, depthPos, lfo;
        a = ~argsOrEvent.(args);
        { |in|
             rateCtl  = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)  ? 3.0)).clip(0.01, 20.0);
             depthCtl = NamedControl.kr((prefix ++ "_depth").asSymbol,  (a.at(\depth) ? 0.5)).clip(0.0, 1.0);
             phaseCtl = NamedControl.kr((prefix ++ "_phase").asSymbol,  (a.at(\phase) ? 0.0));
             depthPos = depthCtl.clip(0.0, 0.999); // avoid fully nulling the carrier
             lfo      = SinOsc.kr(rateCtl, phaseCtl * 2pi).range(1 - depthPos, 1);
            in * lfo
        }
    };

    // ------------------------------------------------------------
    // Flanger
    // rate:   (Hz)     -- LFO rate
    // depth:  (sec)    -- Modulation depth
    // delay:  (sec)    -- Base delay
    // mix:    (0..1)   -- Dry/wet blend
    // ------------------------------------------------------------
    ~fxBuilders[\flanger] = { |prefix, args = nil|
        var a = ~argsOrEvent.(args);
        { |in|
            var rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 0.15)).clip(0.01, 5.0);
            var depthCtl  = NamedControl.kr((prefix ++ "_depth").asSymbol,  (a.at(\depth)  ? 0.004)).clip(0.0001, 0.02);
            var baseDelay = NamedControl.kr((prefix ++ "_delay").asSymbol,  (a.at(\delay)  ? 0.003)).clip(0.0001, 0.02);
            var mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 0.5)).clip(0.0, 1.0);

            var maxDelay  = (baseDelay + depthCtl).clip(0.0005, 0.05);
            var mod       = (baseDelay + SinOsc.kr(rateCtl).range(0, depthCtl)).clip(0.0001, maxDelay - 0.00005);
            var delayed   = DelayL.ar(in, maxDelay, mod);
            XFade2.ar(in, delayed, (mixCtl * 2) - 1)
        }
    };

    // ------------------------------------------------------------
    // Delay
    // time:     (sec)   -- Delay time
    // feedback: (0..1)  -- Feedback amount
    // mix:      (0..1)  -- Dry/wet blend
    // ------------------------------------------------------------
    ~fxBuilders[\delay] = { |prefix, args = nil|
        var a = ~argsOrEvent.(args);
        { |in|
            var timeCtl = NamedControl.kr((prefix ++ "_time").asSymbol,      (a.at(\time)     ? 0.25)).clip(0.001, 1.0);
            var fbCtl   = NamedControl.kr((prefix ++ "_feedback").asSymbol,  (a.at(\feedback) ? 0.35)).clip(0.0, 0.95);
            var mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol,       (a.at(\mix)      ? 0.35)).clip(0.0, 1.0);

            var wet  = DelayC.ar(in, 1.0, timeCtl);
            var loop = (in + (wet * fbCtl));
            XFade2.ar(in, loop, (mixCtl * 2) - 1)
        }
    };

    // ------------------------------------------------------------
    // Utility: Downmix 6 -> 2 (hex -> stereo)
    // amp: (0..2)   -- Output gain
    // ------------------------------------------------------------
    ~fxBuilders[\downmix6to2] = { |prefix, args = nil|
        var a = ~argsOrEvent.(args);
        { |in|
            var ampCtl = NamedControl.kr((prefix ++ "_amp").asSymbol, (a.at(\amp) ? 0.8)).clip(0, 2);
            var n = in.numChannels;
            var stereo = (n == 6).if({
                var l = in[0] + (in[2] * 0.5) + (in[3] * 0.7);
                var r = in[1] + (in[2] * 0.5) + (in[4] * 0.7);
                [l, r]
            }, {
                Splay.ar(in) // fallback for other channel counts
            });
            stereo * ampCtl
        }
    };

    // --- Reserved for future FX ---
    // Add new FX builders here using the same pattern.
)