// test20250904-0954.scd
(
var start;
// --- Choose source mode for this test ---
// \test       -> internal 6-ch hex generator (safe when no device connected)
// \blackhole  -> takes input from SoundIn channels (configure your device & routing)
~sourceMode = (~sourceMode ? \test);

// --- Define a new demo chain (auto-filters missing FX builders) ---
~spec_v6_demo = {
    var wanted, haveFX, midStages;
    // The FX you’d like to hear (adjust to taste)
    wanted = [
        [\chopTrem, (id: \ch1, rate: 8, duty: 0.25, smooth: 0.003, mix: 1.0)],
        [\ringmod,  (id: \rm1, freq: 450, mix: 0.65)],
        [\slapback, (id: \sl1, time: 0.14, decay: 1.6, mix: 0.75,
                     damp: 3200, hp: 120, wobbleRate: 0.5, wobbleDepth: 0.0018)]
    ];

    haveFX = { |sym| (~fxBuilders.notNil) and: { ~fxBuilders[sym].notNil } };
    midStages = wanted.select { |entry| haveFX.(entry[0]) };

    [\guitar] ++ midStages ++ [\destinationStereo]
}.value;

// --- Update GUI model and bring up the v6 GUI ---
~jitCurrentSpec = ~spec_v6_demo;
~jitNextSpec = nil;
(~jitGui_launch ? { ~jitChainGuiWindow.() }).value;  // supports both v6 & compatibility aliases

// --- Build & Play (server-boot safe) ---
start = {
    ~jitBuild.(~spec_v6_demo);  // sets Ndef(\chain)/\out with fadeTime = ~jitFadeTime
    ~jitPlay.();                // plays Ndef(\out) at ~outOffset
    s.meter;
    ~jitStatus.tryPerform(\value);
};

// Optional: align I/O counts heuristically with your ~numCh and downmix
// (Uncomment if you want to control SC’s server options here.)
// s.options.numInputBusChannels  = (~numCh ? 6);
// s.options.numOutputBusChannels = ((~jitUseSplayDownmix ? false) == true).if(2, (~numCh ? 6));

s.serverRunning.if({
    start.value;
}, {
    s.waitForBoot({ start.value });
});
)

// QUEUE A
(
// Queue Next Chain #1 → different params than current
~spec_v6_next1 = {
    var wanted, haveFX, midStages;
    wanted = [
        [\chopTrem, (id: \ch2, rate: 6, duty: 0.33, smooth: 0.004, mix: 0.95)],
        [\ringmod,  (id: \rm2, freq: 700, mix: 0.75)],
        [\slapback, (id: \sl2, time: 0.09, decay: 1.4, mix: 0.65,
                     damp: 3800, hp: 140, wobbleRate: 0.9, wobbleDepth: 0.0012)]
    ];
    haveFX = { |sym| (~fxBuilders.notNil) and: { ~fxBuilders[sym].notNil } };
    midStages = wanted.select { |entry| haveFX.(entry[0]) };
    [\guitar] ++ midStages ++ [\destinationStereo]
}.value;

~jitNextSpec = ~spec_v6_next1;

// GUI refresh (prefers throttled refresh if present)
(~jitGuiRefreshOnce ? { ~jitGuiRefreshOnce.() }).value;
(~jitGuiRefreshOnce.isNil and: { ~jitGui_refresh.notNil }).if({ ~jitGui_refresh.() });
"Queued Next Chain #1 into ~jitNextSpec".postln;
)

// QUEUE B
(
// Queue Next Chain #2 → another flavor
~spec_v6_next2 = {
    var wanted, haveFX, midStages;
    wanted = [
        [\chopTrem, (id: \ch3, rate: 4.5, duty: 0.20, smooth: 0.003, mix: 1.0)],
        [\ringmod,  (id: \rm3, freq: 320, mix: 0.55)],
        [\slapback, (id: \sl3, time: 0.16, decay: 1.9, mix: 0.80,
                     damp: 3000, hp: 110, wobbleRate: 0.6, wobbleDepth: 0.0022)]
    ];
    haveFX = { |sym| (~fxBuilders.notNil) and: { ~fxBuilders[sym].notNil } };
    midStages = wanted.select { |entry| haveFX.(entry[0]) };
    [\guitar] ++ midStages ++ [\destinationStereo]
}.value;

~jitNextSpec = ~spec_v6_next2;

(~jitGuiRefreshOnce ? { ~jitGuiRefreshOnce.() }).value;
(~jitGuiRefreshOnce.isNil and: { ~jitGui_refresh.notNil }).if({ ~jitGui_refresh.() });
"Queued Next Chain #2 into ~jitNextSpec".postln;
)


//ACTIVATE
(
// Activate immediately (if ~jitNextSpec exists)
(~jitNextSpec.notNil).if({
    ~jitBuild.(~jitNextSpec);
    ~jitCurrentSpec = ~jitNextSpec;
    ~jitNextSpec = nil;

    ~jitStatus.tryPerform(\value);

    (~jitGuiRefreshOnce ? { ~jitGuiRefreshOnce.() }).value;
    (~jitGuiRefreshOnce.isNil and: { ~jitGui_refresh.notNil }).if({ ~jitGui_refresh.() });

    "Activated next chain -> current; cleared ~jitNextSpec".postln;
},{
    "No next spec queued. Nothing to activate.".warn;
});
)
