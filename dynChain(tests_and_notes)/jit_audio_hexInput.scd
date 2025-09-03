// jit_audio_hexInput.scd

// MD 20250829 — 6-channel BlackHole input → stereo via Splay

(
s.options.inDevice  = "BlackHole 16ch";
s.options.outDevice = "MacBook Pro Speakers";
s.options.numInputBusChannels  = 6;  // hex pickup
s.options.numOutputBusChannels = 2;  // stereo out
s.reboot;
)

(s.waitForBoot({
Ndef(\hexIn).source = { SoundIn.ar([0, 1, 2, 3, 4, 5]) };
	Ndef(\out).source   = { Splay.ar(Ndef(\hexIn).ar, spread: 1) * 0.8 };
    Ndef(\out).play;
    s.meter;
});)
























/*
below code abandoned because waaaaaaaay too complicated for this.


//
// What this does:
//   1) Sets input to "BlackHole 16ch" and output to "MacBook Pro Speakers".
//   2) Configures 2 input channels (set ~numIn = 6 for hex pickup) and 2 output channels.
//   3) Reboots the server with these options.
//   4) Plays SoundIn via Splay.ar → stereo (all inputs treated equally), then cleanup.
//
// Evaluate each block separately.

// ---------- 0) Configuration (edit names/counts here if needed) ----------
(
~inDeviceName  = (~inDeviceName  ? "BlackHole 16ch");       // CoreAudio input device (exact name)
~outDeviceName = (~outDeviceName ? "MacBook Pro Speakers"); // CoreAudio output device (exact name)

~numIn      = (~numIn      ? 6).asInteger.clip(1, 16);  // set to 6 for hex pickup, then re-run blocks 2+3
~numOut     = (~numOut     ? 2).asInteger.clip(2, 16);  // MBP speakers are 2-ch
~outOffset  = (~outOffset  ? 0).asInteger.max(0);
~sampleRate = (~sampleRate ? nil);                      // e.g., 48000; leave nil for device default
~hexOutAmp  = (~hexOutAmp  ? 0.8).asFloat.clip(0, 2);

// Helper to list devices (optional)
~postAudioDevices = {
    "=== Audio Devices ===".postln;
    ("In : "  ++ ServerOptions.inDevices.asString).postln;
    ("Out: "  ++ ServerOptions.outDevices.asString).postln;
    "======================".postln;
};
)

// ---------- 1) (Optional) Inspect devices ----------
(
~postAudioDevices.();
)

// ---------- 2) Apply options and (re)boot the server ----------
(
var opts, inList, outList, haveIn, haveOut;

opts = Server.default.options;

// Snapshot device lists once (robust check)
inList  = ServerOptions.inDevices.collect(_.asString);
outList = ServerOptions.outDevices.collect(_.asString);

// Case-sensitive exact match (as listed by ServerOptions)
haveIn  = inList.any  { |n| n == ~inDeviceName.asString };
haveOut = outList.any { |n| n == ~outDeviceName.asString };

// Gentle warnings (informational)
(haveIn.not).if({ ("[INFO] Input device name not found in list: "  ++ ~inDeviceName).postln; });
(haveOut.not).if({ ("[INFO] Output device name not found in list: " ++ ~outDeviceName).postln; });

// Apply device selections and channel counts
opts.inDevice  = ~inDeviceName;
opts.outDevice = ~outDeviceName;
opts.numInputBusChannels  = ~numIn;
opts.numOutputBusChannels = ~numOut;

// Optional: enforce a specific sample rate
(~sampleRate.notNil).if({ opts.sampleRate = ~sampleRate; });

// Reboot server to apply changes
"Rebooting server with selected devices...".postln;
s.reboot;

// Post the final options after boot
s.waitForBoot({
    "=== Server Booted with Options ===".postln;
    ("inDevice : " ++ Server.default.options.inDevice).postln;
    ("outDevice: " ++ Server.default.options.outDevice).postln;
    ("numInputBusChannels : " ++ Server.default.options.numInputBusChannels).postln;
    ("numOutputBusChannels: " ++ Server.default.options.numOutputBusChannels).postln;
    ("sampleRate: " ++ Server.default.options.sampleRate.asString).postln;
});
)

// ---------- 3) Splay test: spread N inputs equally across stereo ----------
(
s.waitForBoot({
    // Multi-in capture 0..(~numIn-1)
    Ndef(\hexIn).fadeTime = 0.1;
    Ndef(\hexIn).source = {
        SoundIn.ar( (0 .. (~numIn - 1)) )
    };

    // Even, equal spread across stereo (no custom weights)
    Ndef(\out).fadeTime = 0.1;
    Ndef(\out).source = {
        var in = Ndef(\hexIn).ar; // 2 or 6 channels, etc.
        Splay.ar(in, spread: 1, levelComp: true, center: 0) * ~hexOutAmp
    };

    Ndef(\out).play(~outOffset);
    s.meter;
    ("Now playing: Splay spread of " ++ ~numIn.asString ++ " inputs → stereo.").postln;
});
)


// ---------- 4) Cleanup ----------
(
Ndef(\out).stop(0.1); Ndef(\out).clear;
Ndef(\hexIn).stop(0.1); Ndef(\hexIn).clear;
"Stopped and cleared test proxies.".postln;
)

s.meter;


*/