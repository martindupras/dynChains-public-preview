// jit_test_suite_v3.scd
// MD 20250903 — Minimal chain + CF tests (additive, silent unless failures)

(
~jitTest = ~jitTest ? ();

~jitTest[\assert] = { |cond, label = "assert"|
    var ok;
    ok = (cond == true);
    ok.if({
        ("[PASS] " ++ label).postln;
    },{
        ("[FAIL] " ++ label).warn;
    });
};

~jitTest[\loadDemoSpecsIfNeeded] = {
    var dir, path;
    (~demoSpec_swirl.isNil or: { ~demoSpec_metalDub.isNil }).if({
        dir = thisProcess.nowExecutingPath.dirname;
        path = dir +/+ "jit_demo_chains_v3.scd";
        (PathName(path).isFile).if({
            thisProcess.interpreter.executeFile(path);
        },{
            "[jitTest] demo chains file not found; some tests may skip.".warn;
        });
    });
};

~jitTest[\sanity] = {
    var ok;
    ok = (Ndef(\chain).notNil) and: { Ndef(\out).notNil };
    ~jitTest[\assert].(ok, "Proxies exist (chain/out)");
};

~jitTest[\buildBasic] = {
    var spec, chOk, outOk;
    ~jitTest[\loadDemoSpecsIfNeeded].();
    spec = ~demoSpec_swirl ? [\guitar, \destinationStereo];

    ~jitBuildAndNotify.(spec);
    ~jitPlay.();

    chOk  = (Ndef(\chain).numChannels ? 0) > 0;
    outOk = (Ndef(\out).numChannels ? 0)   > 0;

    ~jitTest[\assert].(chOk,  "Ndef(\\chain) has channels");
    ~jitTest[\assert].(outOk, "Ndef(\\out) has channels");
};

~jitTest[\previewAndSwitchNow] = {
    var a, b, nextShown;
    ~jitTest[\loadDemoSpecsIfNeeded].();
    a = ~demoSpec_swirl ? [\guitar, \destinationStereo];
    b = ~demoSpec_metalDub ? [\guitar, \destinationStereo];

    ~jitBuildAndNotify.(a);
    ~jitCFPreview.(b);
    nextShown = ~jitNextSpec.notNil;
    ~jitTest[\assert].(nextShown, "Next spec shown after preview");

    ~jitCFSwitchNow.();
    // Allow UI refresh
    AppClock.sched(0.1, {
        ~jitTest[\assert].(~jitNextSpec.isNil, "Next cleared after switchNow");
        nil
    });
};

~jitTest[\previewAndSwitchIn] = {
    var a, b;
    ~jitTest[\loadDemoSpecsIfNeeded].();
    a = ~demoSpec_swirl ? [\guitar, \destinationStereo];
    b = ~demoSpec_metalDub ? [\guitar, \destinationStereo];

    ~jitBuildAndNotify.(a);
    ~jitCFPreview.(b);

    // Schedule for 1.0s
    ~jitCFSwitchIn.(1.0);

    // Check before + after
    AppClock.sched(0.2, {
        ~jitTest[\assert].(~jitNextSpec.notNil, "Next present before scheduled switch");
        nil
    });
    AppClock.sched(1.5, {
        ~jitTest[\assert].(~jitNextSpec.isNil,  "Next cleared after scheduled switch");
        nil
    });
};

~jitTest[\mixerActive] = {
    // After any build, Ndef(\out) should be the XFade mixer; prove by scrubbing mix_pos
    ~jitSetCrossfade.(1.5, 0.5);
    ~jitBuildAndNotify.(~demoSpec_swirl ? [\guitar, \destinationStereo]);
    ~jitCFPreview.(~demoSpec_metalDub ? [\guitar, \destinationStereo]);
    ~jitCFSwitchIn.(0.5);

    Routine({
        1.2.wait; Ndef(\out).set(\mix_pos, 0.0);
        0.8.wait; Ndef(\out).set(\mix_pos, 1.0);
        0.2.wait; ~jitTest[\assert].(true, "mix_pos scrubbing executed (audible manual check)");
    }).play(AppClock);
};

// Entry points
~jitRunAll = {
    ~jitTest[\sanity].();
    ~jitTest[\buildBasic].();
    ~jitTest[\previewAndSwitchNow].();
    ~jitTest[\previewAndSwitchIn].();
    ~jitTest[\mixerActive].();
    "[jitTest] scheduled checks are running on AppClock…".postln;
};

~jitRunCFQuick = {
    ~jitTest[\loadDemoSpecsIfNeeded].();
    ~jitSetCrossfade.(2.0, 0.5);
    ~jitGuiShow.();
    ~jitBuildAndNotify.(~demoSpec_swirl);
    ~jitPlay.();
    ~jitCFPreview.(~demoSpec_metalDub);
    ~jitCFSwitchIn.(2.0);
    Routine({
        3.0.wait; Ndef(\out).set(\mix_pos, 0.0);
        1.0.wait; Ndef(\out).set(\mix_pos, 1.0);
    }).play(AppClock);
    "[jitTest] CFQuick started (listen for a clear 2s fade, then manual scrub)".postln;
};

/* Robust CF sequence with run-token guard to avoid flooding */
~jitRunCFRobust = {
    var fade, tail, wait2, runID;

    fade = ~jitCFFade ? (~jitCFFadeTime ? 0.05);
    tail = ~jitCFTail ? (~jitCFTailTime ? 0.20);

    ~jitCFRobustRunID = (~jitCFRobustRunID ? 0) + 1;
    runID = ~jitCFRobustRunID;

    "[jitTest] CFRobust starting…".postln;

    // 1) Preview B (GUI preview spec if present), switch NOW, assert after 0.2s
    AppClock.sched(0, {
        if(runID != (~jitCFRobustRunID ? runID)) { 0 }{
            var specB;
            specB = ~jitGuiPreviewSpec ? ~jitCurrentSpec;
            if(~jitCFPreview.notNil) { ~jitCFPreview.(specB) };
            ~jitCFSwitchNow.();
            "[jitTest] (1) switched NOW; waiting 0.2s…".postln;

            AppClock.sched(0.2, {
                if(runID != (~jitCFRobustRunID ? runID)) { 0 }{
                    if(~jitNextSpec.isNil) {
                        "[PASS] (1) Next cleared after immediate switch".postln;
                    }{
                        "WARNING: [FAIL] (1) Next not cleared after immediate switch".postln;
                    };
                    0
                }
            });
            0
        }
    });

    // 2) Preview A (currentSpec), switchIn(0.5), assert after fade+tail+0.1
    AppClock.sched(0.35, {
        if(runID != (~jitCFRobustRunID ? runID)) { 0 }{
            var specA;
            specA = ~jitCurrentSpec;
            if(~jitCFPreview.notNil) { ~jitCFPreview.(specA) };
            ~jitCFSwitchIn.(0.5);
            "[jitTest] (2) scheduled SwitchIn(0.5); waiting fade+tail+0.1…".postln;

            wait2 = (fade + tail + 0.1).max(0.2);
            AppClock.sched(0.5 + wait2, {
                if(runID != (~jitCFRobustRunID ? runID)) { 0 }{
                    if(~jitNextSpec.isNil) {
                        "[PASS] (2) Next cleared after scheduled switch".postln;
                    }{
                        "WARNING: [FAIL] (2) Next not cleared after scheduled switch".postln;
                    };
                    0
                }
            });
            0
        }
    });

    // 3) Liveness
    AppClock.sched(1.2 + fade + tail, {
        if(runID != (~jitCFRobustRunID ? runID)) { 0 }{
            if(~jitCFAssertLive.notNil) { ~jitCFAssertLive.() };
            "[jitTest] CFRobust complete.".postln;
            0
        }
    });
};


/*~jitRunCFRobust = {
    var fade, tail, wait2;

    fade = ~jitCFFade ? (~jitCFFadeTime ? 0.05);
    tail = ~jitCFTail ? (~jitCFTailTime ? 0.20);

    "[jitTest] CFRobust starting…".postln;

    // 1) Preview B (use GUI preview spec if present), switch NOW, assert after 0.2s
    AppClock.sched(0, {
        var specB;
        specB = ~jitGuiPreviewSpec ? ~jitCurrentSpec;
        if(~jitCFPreview.notNil) { ~jitCFPreview.(specB) };
        ~jitCFSwitchNow.();
        "[jitTest] (1) switched NOW; waiting 0.2s…".postln;

        AppClock.sched(0.2, {
            if(~jitNextSpec.isNil) {
                "[PASS] (1) Next cleared after immediate switch".postln;
            }{
                "WARNING: [FAIL] (1) Next not cleared after immediate switch".postln;
            };
            0
        });
        0
    });

    // 2) Preview A (currentSpec), switchIn(0.5), assert after fade+tail+0.1
    AppClock.sched(0.35, {
        var specA;
        specA = ~jitCurrentSpec;
        if(~jitCFPreview.notNil) { ~jitCFPreview.(specA) };
        ~jitCFSwitchIn.(0.5);
        "[jitTest] (2) scheduled SwitchIn(0.5); waiting fade+tail+0.1…".postln;

        wait2 = (fade + tail + 0.1).max(0.2);
        AppClock.sched(0.5 + wait2, {
            if(~jitNextSpec.isNil) {
                "[PASS] (2) Next cleared after scheduled switch".postln;
            }{
                "WARNING: [FAIL] (2) Next not cleared after scheduled switch".postln;
            };
            0
        });
        0
    });

    // 3) Liveness
    AppClock.sched(1.2 + fade + tail, {
        if(~jitCFAssertLive.notNil) { ~jitCFAssertLive.() };
        "[jitTest] CFRobust complete.".postln;
        0
    });
};*/

/* Immediate switch clears Next deterministically (allow one AppClock tick). */
/* Immediate switch clears Next; allow one tick */
~jitTest_ImmediateSwitchClearsNext = {
    var ensureNext, doSwitch;

    ensureNext = {
        var spec;
        spec = ~jitGuiPreviewSpec ? ~jitCurrentSpec;
        if(~jitCFPreview.notNil) { ~jitCFPreview.(spec) };
        nil
    };

    doSwitch = {
        ~jitCFSwitchNow.();
        AppClock.sched(0.02, {
            if(~jitNextSpec.isNil) { "[PASS] Next cleared after switchNow".postln }
            { "WARNING: [FAIL] Next cleared after switchNow".postln };
            nil  // <-- run once
        });
        nil
    };

    AppClock.sched(0, ensureNext);
    AppClock.sched(0.02, doSwitch);
};

/* Robust CF (with run token) */
~jitRunCFRobust = {
    var fade, tail, wait2, runID;

    fade = ~jitCFFade ? (~jitCFFadeTime ? 0.05);
    tail = ~jitCFTail ? (~jitCFTailTime ? 0.20);

    ~jitCFRobustRunID = (~jitCFRobustRunID ? 0) + 1;
    runID = ~jitCFRobustRunID;

    "[jitTest] CFRobust starting…".postln;

    AppClock.sched(0, {
        if(runID != (~jitCFRobustRunID ? runID)) { nil }{
            var specB = ~jitGuiPreviewSpec ? ~jitCurrentSpec;
            if(~jitCFPreview.notNil) { ~jitCFPreview.(specB) };
            ~jitCFSwitchNow.();
            AppClock.sched(0.2, {
                if(runID == (~jitCFRobustRunID ? runID)) {
                    if(~jitNextSpec.isNil) { "[PASS] (1) Next cleared after immediate switch".postln }
                    { "WARNING: [FAIL] (1) Next not cleared after immediate switch".postln };
                };
                nil
            });
            nil
        }
    });

    AppClock.sched(0.35, {
        if(runID != (~jitCFRobustRunID ? runID)) { nil }{
            var specA = ~jitCurrentSpec;
            if(~jitCFPreview.notNil) { ~jitCFPreview.(specA) };
            ~jitCFSwitchIn.(0.5);
            wait2 = (fade + tail + 0.1).max(0.2);
            AppClock.sched(0.5 + wait2, {
                if(runID == (~jitCFRobustRunID ? runID)) {
                    if(~jitNextSpec.isNil) { "[PASS] (2) Next cleared after scheduled switch".postln }
                    { "WARNING: [FAIL] (2) Next not cleared after scheduled switch".postln };
                };
                nil
            });
            nil
        }
    });

    AppClock.sched(1.2 + fade + tail, {
        if(runID == (~jitCFRobustRunID ? runID)) {
            if(~jitCFAssertLive.notNil) { ~jitCFAssertLive.() };
            "[jitTest] CFRobust complete.".postln;
        };
        nil
    });
};

)
