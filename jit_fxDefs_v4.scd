// jit_fxDefs_v4.scd
// MD 20250903 — JITLib FX builders (v4):
// - Controls inside UGen funcs
// - vars-first, caret-free, tilde-globals only
// - Adds chopTrem, ringmod, slapback
// - Includes ~fxMeta for GUI parameter ranges/defaults

(
~fxBuilders = IdentityDictionary.new;

// Helper: coerce nil -> empty Event so a.at(\key) ? default works safely
~argsOrEvent = { |args|
    if(args.isNil) { () } { args }
};


// ------------------------------------------------------------
// Tremolo (stable LFO range)
//   rate  (Hz)
//   depth (0..1)
//   phase (0..1 -> radians offset by * 2pi)
// ------------------------------------------------------------
~fxBuilders[\tremolo] = { |prefix, args = nil|
    var a;
    a = ~argsOrEvent.(args);

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
    var a;
    a = ~argsOrEvent.(args);

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
    var a;
    a = ~argsOrEvent.(args);

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
// Chop Tremolo (hard gate with duty cycle + edge smoothing)
//   rate   (Hz)
//   duty   (0..1)
//   smooth (sec) - rise/fall smoothing for edges
//   mix    (0..1) - dry/wet blend
// ------------------------------------------------------------
~fxBuilders[\chopTrem] = { |prefix, args = nil|
    var a;
    a = ~argsOrEvent.(args);

    { |in|
        var rateCtl, dutyCtl, smoothCtl, mixCtl, gate, shaped, wet;
        rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 8.0)).clip(0.05, 30.0);
        dutyCtl   = NamedControl.kr((prefix ++ "_duty").asSymbol,   (a.at(\duty)   ? 0.25)).clip(0.01, 0.99);
        smoothCtl = NamedControl.kr((prefix ++ "_smooth").asSymbol, (a.at(\smooth) ? 0.003)).clip(0.0, 0.05);
        mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 1.0)).clip(0.0, 1.0);

        gate   = LFPulse.kr(rateCtl, 0, dutyCtl);
        shaped = LagUD.kr(gate, smoothCtl, smoothCtl);  // soften edges symmetrically
        wet    = in * shaped;

        XFade2.ar(in, wet, (mixCtl * 2) - 1)
    }
};

// ------------------------------------------------------------
// Ring Modulator
//   freq (Hz)
//   mix  (0..1)  - dry/wet blend
//   phase (0..1) optional phase offset
// ------------------------------------------------------------
~fxBuilders[\ringmod] = { |prefix, args = nil|
    var a;
    a = ~argsOrEvent.(args);

    { |in|
        var freqCtl, mixCtl, phaseCtl, mod, wet;
        freqCtl  = NamedControl.kr((prefix ++ "_freq").asSymbol,  (a.at(\freq)  ? 500)).clip(10, 12000);
        mixCtl   = NamedControl.kr((prefix ++ "_mix").asSymbol,   (a.at(\mix)   ? 0.85)).clip(0.0, 1.0);
        phaseCtl = NamedControl.kr((prefix ++ "_phase").asSymbol, (a.at(\phase) ? 0.0));

        mod = SinOsc.ar(freqCtl, phaseCtl * 2pi);
        wet = in * mod;

        XFade2.ar(in, wet, (mixCtl * 2) - 1)
    }
};

// ------------------------------------------------------------
// Slapback Delay (short echo; wobble modulation; simple tone shaping)
//   time        (sec)       0.03 .. 0.25 typical
//   decay       (sec @60dB) Comb* uses decayTime (time to -60dB)
//   mix         (0..1)
//   damp        (Hz)  low-pass cutoff on the echo
//   hp          (Hz)  high-pass cutoff on the echo
//   wobbleRate  (Hz)  delay-time modulation rate
//   wobbleDepth (sec) peak modulation depth added to 'time'
// ------------------------------------------------------------
~fxBuilders[\slapback] = { |prefix, args = nil|
    var a;
    a = ~argsOrEvent.(args);

    { |in|
        var timeCtl, decayCtl, mixCtl, dampCtl, hpCtl, wobRateCtl, wobDepthCtl;
        var baseTime, wob, dtime, maxDelay, wet, shaped;

        timeCtl     = NamedControl.kr((prefix ++ "_time").asSymbol,        (a.at(\time)        ? 0.12)).clip(0.02, 0.35);
        decayCtl    = NamedControl.kr((prefix ++ "_decay").asSymbol,       (a.at(\decay)       ? 1.8)).clip(0.05, 8.0);
        mixCtl      = NamedControl.kr((prefix ++ "_mix").asSymbol,         (a.at(\mix)         ? 0.9)).clip(0.0, 1.0);
        dampCtl     = NamedControl.kr((prefix ++ "_damp").asSymbol,        (a.at(\damp)        ? 3200)).clip(200, 16000);
        hpCtl       = NamedControl.kr((prefix ++ "_hp").asSymbol,          (a.at(\hp)          ? 120)).clip(20, 1000);
        wobRateCtl  = NamedControl.kr((prefix ++ "_wobbleRate").asSymbol,  (a.at(\wobbleRate)  ? 0.7)).clip(0.0, 5.0);
        wobDepthCtl = NamedControl.kr((prefix ++ "_wobbleDepth").asSymbol, (a.at(\wobbleDepth) ? 0.002)).clip(0.0, 0.01);

        baseTime = timeCtl;
        wob      = SinOsc.kr(wobRateCtl).range(0, wobDepthCtl);
        dtime    = (baseTime + wob).clip(0.005, 0.5);
        maxDelay = (dtime + 0.01).clip(0.02, 0.6);

        // CombL: feedback delay with decay time specified in seconds to -60 dB
        wet    = CombL.ar(in, maxDelay, dtime, decayCtl);

        // Tone-shape the echo (HP->LP)
        shaped = LPF.ar(HPF.ar(wet, hpCtl), dampCtl);

        XFade2.ar(in, shaped, (mixCtl * 2) - 1)
    }
};

// ------------------------------------------------------------
// Utility: Downmix N -> 2 (not used by main chain; kept for ad-hoc tests)
//   amp (0..2)
// ------------------------------------------------------------
~fxBuilders[\downmix6to2] = { |prefix, args = nil|
    var a;
    a = ~argsOrEvent.(args);

    { |in|
        var ampCtl, n, l, r, stereo, arr;
        ampCtl = NamedControl.kr((prefix ++ "_amp").asSymbol, (a.at(\amp) ? 0.8)).clip(0, 2);

        arr = in.isArray.if({ in }, { [in] });
        n   = arr.size;

        stereo = (n == 6).if({
            l = arr[0] + (arr[2] * 0.5) + (arr[3] * 0.7);
            r = arr[1] + (arr[2] * 0.5) + (arr[4] * 0.7);
            [l, r]
        }, {
            Splay.ar(arr) // fallback for other counts
        });

        stereo * ampCtl
    }
};

// ------------------------------------------------------------
// Optional: parameter metadata for GUI binding / validation
//   Structure: ~fxMeta[\fxSymbol] = ( param: (min: , max: , default: , warp: \lin|\exp) )
// ------------------------------------------------------------
~fxMeta = IdentityDictionary[
    \tremolo -> (
        rate:   (min: 0.01,  max: 20.0,    default: 3.0,   warp: \exp),
        depth:  (min: 0.0,   max: 1.0,     default: 0.5,   warp: \lin),
        phase:  (min: 0.0,   max: 1.0,     default: 0.0,   warp: \lin)
    ),
    \flanger -> (
        rate:   (min: 0.01,  max: 5.0,     default: 0.15,  warp: \exp),
        depth:  (min: 0.0001,max: 0.02,    default: 0.004, warp: \exp),
        delay:  (min: 0.0001,max: 0.02,    default: 0.003, warp: \exp),
        mix:    (min: 0.0,   max: 1.0,     default: 0.5,   warp: \lin)
    ),
    \delay -> (
        time:     (min: 0.001, max: 1.0,   default: 0.25,  warp: \exp),
        feedback: (min: 0.0,   max: 0.95,  default: 0.35,  warp: \lin),
        mix:      (min: 0.0,   max: 1.0,   default: 0.35,  warp: \lin)
    ),
    \chopTrem -> (
        rate:   (min: 0.05,  max: 30.0,    default: 8.0,   warp: \exp),
        duty:   (min: 0.01,  max: 0.99,    default: 0.25,  warp: \lin),
        smooth: (min: 0.0,   max: 0.05,    default: 0.003, warp: \exp),
        mix:    (min: 0.0,   max: 1.0,     default: 1.0,   warp: \lin)
    ),
    \ringmod -> (
        freq:  (min: 10,     max: 12000,   default: 500,   warp: \exp),
        mix:   (min: 0.0,    max: 1.0,     default: 0.85,  warp: \lin),
        phase: (min: 0.0,    max: 1.0,     default: 0.0,   warp: \lin)
    ),
    \slapback -> (
        time:        (min: 0.02,  max: 0.35,  default: 0.12,  warp: \exp),
        decay:       (min: 0.05,  max: 8.0,   default: 1.8,   warp: \exp),
        mix:         (min: 0.0,   max: 1.0,   default: 0.9,   warp: \lin),
        damp:        (min: 200,   max: 16000, default: 3200,  warp: \exp),
        hp:          (min: 20,    max: 1000,  default: 120,   warp: \exp),
        wobbleRate:  (min: 0.0,   max: 5.0,   default: 0.7,   warp: \lin),
        wobbleDepth: (min: 0.0,   max: 0.01,  default: 0.002, warp: \exp)
    ),
    \downmix6to2 -> (
        amp:   (min: 0.0,   max: 2.0,     default: 0.8,   warp: \lin)
    )
];
)
