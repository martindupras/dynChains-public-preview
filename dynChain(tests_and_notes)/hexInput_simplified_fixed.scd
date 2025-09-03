// hexInput_simplified_fixed.scd
// Safer variant (no range operator): explicit channel array to avoid parser quirks
(
    s.options.inDevice  = "BlackHole 16ch";
    s.options.outDevice = "MacBook Pro Speakers";
    s.options.numInputBusChannels  = 6;
    s.options.numOutputBusChannels = 2;
    s.reboot;
)

s.waitForBoot({
    Ndef(\hexIn).fadeTime = 0.1;
    Ndef(\hexIn).source = { SoundIn.ar([0, 1, 2, 3, 4, 5]) };  // explicit list
    Ndef(\out).fadeTime = 0.1;
    Ndef(\out).source = {
        var in = Ndef(\hexIn).ar;
        Splay.ar(in, spread: 1, levelComp: true) * 0.8
    };

    Ndef(\out).play;
    s.meter;
});

// Cleanup
(
    Ndef(\out).stop(0.1); Ndef(\out).clear;
    Ndef(\hexIn).stop(0.1); Ndef(\hexIn).clear;
)
