//jit_test_gui_v3.scd
// MD 20250902-1320

// 1) Show GUI
~jitGuiShow.();

// 2) Build a chain with notifications (row 1)
~jitBuildAndNotify.(~demoSpec_swirl);

// 3) Preview a new chain as "next" (row 2 appears)
~jitSetNextSpec.(~demoSpec_metalDub);

// 4) Switch now (or use ~jitScheduleSwitchToNext.(2.0))
~jitSwitchToNextNow.();

// 5) Silent status check (should return an Event)
~jitStatus.().postln;

