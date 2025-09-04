// fx_delays_v6.scd
// Delay-based effects. Slapback: short delay with feedback, simple HP/LP damping, optional wobble.

(
~jitFxRegister.(\slapback, { |prefix, args|
    var id = prefix.asString;
    var timeD, decayD, mixD, dampD, hpD, wobRateD, wobDepthD, maxDelay;

    timeD     = ~jitFxParam.(args, \time,       0.12);   // seconds
    decayD    = ~jitFxParam.(args, \decay,      1.8);    // RT60-ish seconds
    mixD      = ~jitFxParam.(args, \mix,        0.9);
    dampD     = ~jitFxParam.(args, \damp,       3200);   // LPF Hz
    hpD       = ~jitFxParam.(args, \hp,         120);    // HPF Hz
    wobRateD  = ~jitFxParam.(args, \wobbleRate, 0.7);    // Hz
    wobDepthD = ~jitFxParam.(args, \wobbleDepth,0.002);  // seconds
    maxDelay  = 1.0;  // safe upper bound

    { |in|
        var kTime, kDecay, kMix, kDamp, kHp, kWobR, kWobD, dMod, dTime, wet, sig;

        sig   = in;
        kTime = NamedControl.kr((id ++ "_time").asSymbol,       timeD);
        kDecay= NamedControl.kr((id ++ "_decay").asSymbol,      decayD);
        kMix  = NamedControl.kr((id ++ "_mix").asSymbol,        mixD);
        kDamp = NamedControl.kr((id ++ "_damp").asSymbol,       dampD);
        kHp   = NamedControl.kr((id ++ "_hp").asSymbol,         hpD);
        kWobR = NamedControl.kr((id ++ "_wobRate").asSymbol,    wobRateD);
        kWobD = NamedControl.kr((id ++ "_wobDepth").asSymbol,   wobDepthD);

        dMod  = SinOsc.kr(kWobR, 0, kWobD, 0);
        dTime = (kTime + dMod).clip(0.001, maxDelay - 0.01);

        // CombL: delaytime + decaytime; reasonable for slapback flavor
        wet = CombL.ar(sig, maxDelay, dTime, kDecay);
        wet = HPF.ar(LPF.ar(wet, kDamp.max(20)), kHp.max(10));
        wet = LeakDC.ar(wet);

        ~jitFxDryWet.(sig, wet, kMix)
    }
});
)
