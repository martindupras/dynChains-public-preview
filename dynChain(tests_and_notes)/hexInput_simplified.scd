// hexInput_simplified.scd
// Minimal: 6‑ch BlackHole input → Splay to stereo via Ndefs
(
    s.options.inDevice  = "BlackHole 16ch";
    s.options.outDevice = "MacBook Pro Speakers";
    s.options.numInputBusChannels  = 6;
    s.options.numOutputBusChannels = 2;
    s.reboot;
)

s.waitForBoot({
    Ndef(\hexIn).source = { SoundIn.ar(0 .. 5) };   // NOTE: spaces around `..`
    Ndef(\out).source   = { Splay.ar(Ndef(\hexIn).ar, spread: 1, levelComp: true) * 0.8 };
    Ndef(\out).play;
    s.meter;
});

// Cleanup
(
    Ndef(\out).clear;
    Ndef(\hexIn).clear;
)
