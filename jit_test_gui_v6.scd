// jit_test_gui_v6.scd
// MD 20250903-1647

// 1) Show GUI (v6 entry point)
~jitChainGuiWindow.();

// 2) Build a chain with notifications (row 1)
~jitBuildAndNotify.(~demoChainSpec);

// 3) Preview a new chain as "next" (row 2 appears)
~jitSetNextSpec.(~demoChainSpec2);  // Make sure ~demoChainSpec2 is defined

// 4) Switch now (or use ~jitScheduleSwitchToNext.(2.0))
~jitSwitchToNextNow.();

// 5) Silent status check (should return an Event)
~jitStatus.().postln;