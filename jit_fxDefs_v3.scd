// jit_fxDefs_v3.scd
// MD 20250902 — JITLib FX builders: controls inside UGen funcs, vars-first, caret-free

(
~fxBuilders = IdentityDictionary.new;

// Helper: coerce nil -> empty Event so a.at(\key) ? default works safely
~argsOrEvent = { |args| args ? () };

// ------------------------------------------------------------
// Tremolo (stable LFO range)
//   rate  (Hz)
//   depth (0..1)
//   phase (0..1 -> radians offset by * 2pi)
// ------------------------------------------------------------
~fxBuilders[\tremolo] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);

    { |in|
        var rateCtl, depthCtl, phaseCtl, depthPos, lfo;

        rateCtl  = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)  ? 3.0)).clip(0.01, 20.0);
        depthCtl = NamedControl.kr((prefix ++ "_depth").asSymbol,  (a.at(\depth) ? 0.5)).clip(0.0, 1.0);
        phaseCtl = NamedControl.kr((prefix ++ "_phase").asSymbol,  (a.at(\phase) ? 0.0));

        depthPos = depthCtl.clip(0.0, 0.999); // avoid fully nulling the carrier by accident
        lfo = SinOsc.kr(rateCtl, phaseCtl * 2pi).range(1 - depthPos, 1);
        in * lfo
    }
};

// ------------------------------------------------------------
// Flanger (stable: bounded delay; per-channel safe)
//   rate   (Hz)
//   depth  (sec)    modulation depth
//   delay  (sec)    base delay
//   mix    (0..1)   0=dry, 1=wet (mapped to XFade2 pan)
// ------------------------------------------------------------
~fxBuilders[\flanger] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);

    { |in|
        var rateCtl, depthCtl, baseDelay, mixCtl, maxDelay, mod, delayed;

        rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 0.15)).clip(0.01, 5.0);
        depthCtl  = NamedControl.kr((prefix ++ "_depth").asSymbol,  (a.at(\depth)  ? 0.004)).clip(0.0001, 0.02);
        baseDelay = NamedControl.kr((prefix ++ "_delay").asSymbol,  (a.at(\delay)  ? 0.003)).clip(0.0001, 0.02);
        mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 0.5)).clip(0.0, 1.0);

        maxDelay  = (baseDelay + depthCtl).clip(0.0005, 0.05);
        mod       = (baseDelay + SinOsc.kr(rateCtl).range(0, depthCtl)).clip(0.0001, maxDelay - 0.00005);

        delayed   = DelayL.ar(in, maxDelay, mod);
        XFade2.ar(in, delayed, (mixCtl * 2) - 1)
    }
};

// ------------------------------------------------------------
// Delay (feed-forward/feedback blend)
//   time     (sec)
//   feedback (0..1)
//   mix      (0..1)
// ------------------------------------------------------------
~fxBuilders[\delay] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);

    { |in|
        var timeCtl, fbCtl, mixCtl, wet, loop;

        timeCtl = NamedControl.kr((prefix ++ "_time").asSymbol,      (a.at(\time)     ? 0.25)).clip(0.001, 1.0);
        fbCtl   = NamedControl.kr((prefix ++ "_feedback").asSymbol,  (a.at(\feedback) ? 0.35)).clip(0.0, 0.95);
        mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol,       (a.at(\mix)      ? 0.35)).clip(0.0, 1.0);

        wet  = DelayC.ar(in, 1.0, timeCtl);
        loop = (in + (wet * fbCtl));

        XFade2.ar(in, loop, (mixCtl * 2) - 1)
    }
};

// ------------------------------------------------------------
// Utility: Downmix 6 -> 2 (not used by main chain; kept for ad-hoc tests)
//   amp (0..2)
// ------------------------------------------------------------
~fxBuilders[\downmix6to2] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);

    { |in|
        var ampCtl, n, l, r, stereo;

        ampCtl = NamedControl.kr((prefix ++ "_amp").asSymbol, (a.at(\amp) ? 0.8)).clip(0, 2);

        n = in.numChannels;
        stereo = (n == 6).if({
            l = in[0] + (in[2] * 0.5) + (in[3] * 0.7);
            r = in[1] + (in[2] * 0.5) + (in[4] * 0.7);
            [l, r]
        }, {
            Splay.ar(in) // fallback for other counts
        });

        stereo * ampCtl
    }
};
)
