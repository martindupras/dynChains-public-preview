// -----------------------------------------------------------
// jit_test_suite_v4.scd
// Deterministic tests for v4 CF engine
// -----------------------------------------------------------

(
~jitTestRunToken_v4 = ~jitTestRunToken_v4 ? 0;
~jitCFEnsureMixer.();

~jitTest_ProxySanity_v4 = {
    var ch, outCh;
    ch = Ndef(\chain).numChannels ? -1;
    outCh = Ndef(\out).numChannels ? -1;

    if(ch > 0) { "[PASS] Ndef(\\chain) has channels".postln } { "WARNING: [FAIL] Ndef(\\chain) has no channels".postln };
    if(outCh > 0) { "[PASS] Ndef(\\out) has channels".postln } { "WARNING: [FAIL] Ndef(\\out) has no channels".postln };
};

~jitTest_ImmediateSwitchClearsNext_v4 = {
    var ensureNext, doSwitch;

    ensureNext = {
        var spec;
        spec = ~jitGuiPreviewSpec ? (~jitCurrentSpec ? [\\guitar, \\destination]);
        if(~jitCFPreview.notNil) { ~jitCFPreview.(spec) };
        nil
    };

    doSwitch = {
        ~jitCFSwitchNow.();
        AppClock.sched(0.02, {
            if(~jitNextSpec.isNil) {
                "[PASS] Next cleared after switchNow".postln;
            }{
                "WARNING: [FAIL] Next cleared after switchNow".postln;
            };
            nil
        });
        nil
    };

    AppClock.sched(0, ensureNext);
    AppClock.sched(0.02, doSwitch);
};

~jitTest_ScheduledSwitchClearsNext_v4 = {
    var specA, fade, tail, wait;
    specA = ~jitCurrentSpec ? (~jitGuiPreviewSpec ? [\\guitar, \\destination]);
    fade = ~jitCFFadeTime ? 0.08;
    tail = ~jitCFTailTime ? 0.25;
    wait = (0.5 + fade + tail + 0.1);

    ~jitCFPreview.(specA);
    ("[TEST] Next set? " ++ (~jitNextSpec.isNil.not)).postln;

    ~jitCFSwitchIn.(0.5);

    AppClock.sched(wait, {
        if(~jitNextSpec.isNil) {
            "[PASS] Next cleared after scheduled switch".postln;
        }{
            "WARNING: [FAIL] Next not cleared after scheduled switch".postln;
        };
        nil
    });
};

~jitTest_LiveAfter2s_v4 = {
    AppClock.sched(2.1, {
        ("[LIVE] outA playing: " ++ Ndef(\\outA).isPlaying).postln;
        ("[LIVE] outB playing: " ++ Ndef(\\outB).isPlaying).postln;
        ("[LIVE] mixer present? " ++ Ndef(\\out).source.notNil).postln;
        nil
    });
};

~jitRunAll_v4 = {
    var runID;
    ~jitTestRunToken_v4 = (~jitTestRunToken_v4 ? 0) + 1;
    runID = ~jitTestRunToken_v4;

    "[jitTest v4] starting…".postln;

    {
        var spec;
        spec = ~jitGuiPreviewSpec ? (~jitCurrentSpec ? [\\guitar, \\destination]);
        if(~jitCurrentSpec.isNil) {
            if(~jitBuildAndNotify.notNil) { ~jitBuildAndNotify.(spec) } { if(~jitBuild.notNil) { ~jitBuild.(spec) } };
            ~jitCurrentSpec = spec;
        };
        if(~jitTmpMakeMinimalGui_v4.notNil and: { ~jitTmpGuiWindow.isNil }) { ~jitTmpMakeMinimalGui_v4.() };
        if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
    }.defer;

    AppClock.sched(0.1, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            ~jitTest_ProxySanity_v4.();
            nil
        }
    });

    AppClock.sched(0.2, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            ~jitTest_ImmediateSwitchClearsNext_v4.();
            nil
        }
    });

    AppClock.sched(0.5, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            ~jitTest_ScheduledSwitchClearsNext_v4.();
            nil
        }
    });

    AppClock.sched(1.0, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            ~jitTest_LiveAfter2s_v4.();
            "[jitTest v4] scheduled checks enqueued.".postln;
            nil
        }
    });
};

~jitRunCFRobust_v4 = {
    var runID, fade, tail, wait2;
    ~jitTestRunToken_v4 = (~jitTestRunToken_v4 ? 0) + 1;
    runID = ~jitTestRunToken_v4;

    fade = ~jitCFFadeTime ? 0.08;
    tail = ~jitCFTailTime ? 0.25;

    "[jitTest v4] CFRobust starting…".postln;

    AppClock.sched(0, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            var specB;
            specB = ~jitGuiPreviewSpec ? (~jitCurrentSpec ? [\\guitar, \\destination]);
            ~jitCFPreview.(specB);
            ~jitCFSwitchNow.();
            AppClock.sched(0.2, {
                if(runID != ~jitTestRunToken_v4) { nil }{
                    if(~jitNextSpec.isNil) { "[PASS] (1) Next cleared after immediate switch".postln }
                    { "WARNING: [FAIL] (1) Next not cleared after immediate switch".postln };
                    nil
                }
            });
            nil
        }
    });

    AppClock.sched(0.35, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            var specA;
            specA = ~jitCurrentSpec ? (~jitGuiPreviewSpec ? [\\guitar, \\destination]);
            ~jitCFPreview.(specA);
            ~jitCFSwitchIn.(0.5);

            wait2 = (fade + tail + 0.1).max(0.2);
            AppClock.sched(0.5 + wait2, {
                if(runID != ~jitTestRunToken_v4) { nil }{
                    if(~jitNextSpec.isNil) { "[PASS] (2) Next cleared after scheduled switch".postln }
                    { "WARNING: [FAIL] (2) Next not cleared after scheduled switch".postln };
                    nil
                }
            });
            nil
        }
    });

    AppClock.sched(1.2 + fade + tail, {
        if(runID != ~jitTestRunToken_v4) { nil }{
            if(~jitCFAssertLive.notNil) { ~jitCFAssertLive.() };
            "[jitTest v4] CFRobust complete.".postln;
            nil
        }
    });
};

) // end block
