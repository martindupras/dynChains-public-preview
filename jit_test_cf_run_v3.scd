// jit_test_cf_run_v3.scd
// MD 20250902 — Crossfade preview/switch tests (CF if present; instant fallback otherwise)

(
// Optional: temporary listener to see notifications in the post window
~jitCFTestListener = { |phase, payload|
    var p;
    p = payload ? ();
    ("[CF-TEST] %  →  %".format(phase, p)).postln;
};
~jitAddListener.(~jitCFTestListener);

// Ensure GUI is visible
~jitGuiShow.();

// Two distinct chains for A/B
~cfSpec_A = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 7, duty: 0.25, smooth: 0.002, mix: 1.0)],
    [\slapback, (id:\sl1, time: 0.11, decay: 1.9, mix: 0.9, damp: 3000, hp: 120, wobbleRate: 0.5, wobbleDepth: 0.002)],
    \destinationStereo
];

~cfSpec_B = [
    \guitar,
    [\flanger,  (id:\fl1, rate: 0.12, depth: 0.006, delay: 0.004, mix: 0.85)],
    [\delay,    (id:\d1,  time: 0.28, feedback: 0.62, mix: 0.75)],
    \destinationStereo
];

// 1) Build A as current and play (ensures listeners refresh)
~jitBuildAndNotify.(~cfSpec_A);
~jitPlay.();
s.meter;

// 2) Preview B into inactive & second row (willBuildInactive/didBuildInactive events)
~jitCFPreview.(~cfSpec_B);

// 3) Schedule CF switch in 2.0s (willSwitch posted immediately; didSwitch after)
~jitCFSwitchIn.(2.0);

// 4) Silent status Event (fade/tail reflect CF or defaults)
~jitStatus.().postln;
)

// Optional: toggle A/B a few times to feel ramps
(
// Pull current fade/tail
var ft, tl;
ft = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
tl = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 });

// Toggle B then A, 3 cycles, every 3 seconds + (fade+tail)
Routine({
    var i;
    i = 0;
    while({ i < 3 }, {
        ~jitCFPreview.(~cfSpec_B); ~jitCFSwitchIn.(3.0, ft, tl);
        (3.0 + ft + tl + 0.5).wait;

        ~jitCFPreview.(~cfSpec_A); ~jitCFSwitchIn.(3.0, ft, tl);
        (3.0 + ft + tl + 0.5).wait;

        i = i + 1;
    });
}).play(AppClock);
)

// Cleanup helper (run when done testing)
(
// Remove test listener so it doesn’t keep logging
(~jitRemoveListener ? { |fn| ~jitListeners = (~jitListeners ? []).reject(_ == fn) }).value(~jitCFTestListener);
"[CF-TEST] listener removed".postln;
)
