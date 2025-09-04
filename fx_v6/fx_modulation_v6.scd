// fx_modulation_v6.scd
// Modulation effects (tremolo, ringmod, etc). Each registers a builder with ~jitFxRegister.

(
// ---- Chop Trem (rate, duty, smooth, mix) ----
~jitFxRegister.(\chopTrem, { |prefix, args|
    var id = prefix.asString;
    var rateD, dutyD, smoothD, mixD;

    rateD   = ~jitFxParam.(args, \rate,   6.0);
    dutyD   = ~jitFxParam.(args, \duty,   0.5);
    smoothD = ~jitFxParam.(args, \smooth, 0.003);
    mixD    = ~jitFxParam.(args, \mix,    1.0);

    { |in|
        var kRate, kDuty, kSmooth, kMix, env, wet;
        var sig = in;  // multichannel OK
        kRate   = NamedControl.kr((id ++ "_rate").asSymbol,   rateD);
        kDuty   = NamedControl.kr((id ++ "_duty").asSymbol,   dutyD);
        kSmooth = NamedControl.kr((id ++ "_smooth").asSymbol, smoothD);
        kMix    = NamedControl.kr((id ++ "_mix").asSymbol,    mixD);

        env = LFPulse.kr(kRate, 0, kDuty).lag(kSmooth);
        wet = sig * env;
        ~jitFxDryWet.(sig, wet, kMix)
    }
});

// ---- Ring Mod (freq, mix) ----
~jitFxRegister.(\ringmod, { |prefix, args|
    var id = prefix.asString;
    var freqD, mixD;

    freqD = ~jitFxParam.(args, \freq, 500.0);
    mixD  = ~jitFxParam.(args, \mix,    0.85);

    { |in|
        var kFreq, kMix, mod, wet, num;
        var sig = in;
        num  = (sig.isArray).if({ sig.size }, { 1 });
        kFreq = NamedControl.kr((id ++ "_freq").asSymbol, freqD);
        kMix  = NamedControl.kr((id ++ "_mix").asSymbol,  mixD);
        mod = SinOsc.ar(kFreq ! num);
        wet = sig * mod;
        ~jitFxDryWet.(sig, wet, kMix)
    }
});
)
