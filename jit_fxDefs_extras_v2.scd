// jit_fxDefs_extras_v2.scd
// MD 20250829 — Extra-loud/obvious FX: chopping tremolo, springy slapback, ring mod

(
~fxBuilders = (~fxBuilders ? IdentityDictionary.new);

// Fallback (normally defined in jit_fxDefs_v2)
~argsOrEvent = (~argsOrEvent ? { |args| args ? () });

/* ------------------------------------------------------------
   Chopping Tremolo (gate/pulse AM)
     rate   (Hz)
     duty   (0..1)   on-time proportion of each cycle
     smooth (sec)    small lag to soften edges (0 = hard chop)
     mix    (0..1)   0=dry, 1=fully chopped
   ------------------------------------------------------------ */
~fxBuilders[\chopTrem] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);
    { |in|
        var rateCtl, dutyCtl, smoothCtl, mixCtl, gate;

        rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 8.0)).clip(0.1, 25.0);
        dutyCtl   = NamedControl.kr((prefix ++ "_duty").asSymbol,   (a.at(\duty)   ? 0.25)).clip(0.01, 0.99);
        smoothCtl = NamedControl.kr((prefix ++ "_smooth").asSymbol, (a.at(\smooth) ? 0.003)).clip(0.0, 0.05);
        mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 1.0)).clip(0.0, 1.0);

        gate = Lag.kr(LFPulse.kr(rateCtl, 0, dutyCtl), smoothCtl); // 0..1
        XFade2.ar(in, in * gate, (mixCtl * 2) - 1)
    }
};

/* ------------------------------------------------------------
   Slapback Echo (comb with tone + wow)
     time        (sec)   base delay, slap region
     decay       (sec)   how long repeats persist (comb decay)
     mix         (0..1)  wet/dry
     damp        (Hz)    lowpass on repeats (darkens)
     hp          (Hz)    highpass to thin lows (springy)
     wobbleRate  (Hz)    wow (slow delay modulation)
     wobbleDepth (sec)   wow depth
   ------------------------------------------------------------ */
~fxBuilders[\slapback] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);
    { |in|
        var timeCtl, decayCtl, mixCtl, dampCtl, hpCtl, wobRateCtl, wobDepthCtl;
        var modTime, maxDelay, wet;

        timeCtl     = NamedControl.kr((prefix ++ "_time").asSymbol,        (a.at(\time)        ? 0.12)).clip(0.03, 0.25);
        decayCtl    = NamedControl.kr((prefix ++ "_decay").asSymbol,       (a.at(\decay)       ? 1.6)).clip(0.1, 4.0);
        mixCtl      = NamedControl.kr((prefix ++ "_mix").asSymbol,         (a.at(\mix)         ? 0.9)).clip(0.0, 1.0);
        dampCtl     = NamedControl.kr((prefix ++ "_damp").asSymbol,        (a.at(\damp)        ? 3500)).clip(500, 18000);
        hpCtl       = NamedControl.kr((prefix ++ "_hp").asSymbol,          (a.at(\hp)          ? 120)).clip(20, 2000);
        wobRateCtl  = NamedControl.kr((prefix ++ "_wobbleRate").asSymbol,  (a.at(\wobbleRate)  ? 0.7)).clip(0.0, 5.0);
        wobDepthCtl = NamedControl.kr((prefix ++ "_wobbleDepth").asSymbol, (a.at(\wobbleDepth) ? 0.002)).clip(0.0, 0.02);

        // FIX: use .madd (a * b + c) rather than .mulAdd
        modTime  = SinOsc.kr(wobRateCtl).madd(wobDepthCtl, timeCtl).clip(0.02, 0.35);
        maxDelay = (timeCtl + wobDepthCtl + 0.02).clip(0.05, 0.6);

        wet = CombC.ar(in, maxDelay, modTime, decayCtl);
        wet = HPF.ar(wet, hpCtl);
        wet = LPF.ar(wet, dampCtl);

        XFade2.ar(in, wet, (mixCtl * 2) - 1)
    }
};

/* ------------------------------------------------------------
   Ring Modulator
     freq  (Hz)
     mix   (0..1)  0=dry, 1=full ring
   ------------------------------------------------------------ */
~fxBuilders[\ringmod] = { |prefix, args = nil|
    var a = ~argsOrEvent.(args);
    { |in|
        var freqCtl, mixCtl, carrier;

        freqCtl = NamedControl.kr((prefix ++ "_freq").asSymbol, (a.at(\freq) ? 500)).clip(0.5, 8000);
        mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol,  (a.at(\mix)  ? 0.85)).clip(0.0, 1.0);

        carrier = (SinOsc.ar(freqCtl) ! in.numChannels);
        XFade2.ar(in, in * carrier, (mixCtl * 2) - 1)
    }
};
)
