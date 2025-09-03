// jit_session_hexSplay_demo_v4.scd
// MD 20250903 — 6ch BlackHole → Splay stereo, with loud demo FX (chop trem, slapback, ringmod)

/////////////////////////// 0) I/O and server reboot ///////////////////////////
(
s.options.inDevice  = "BlackHole 16ch";
s.options.outDevice = "MacBook Pro Speakers";
s.options.numInputBusChannels  = 6;
s.options.numOutputBusChannels = 2;
s.reboot;

s.waitForBoot({
    var root, work;
    var extrasPathV4, extrasPathV3, extrasPathV2;
    var haveExtrasV4, haveExtrasV3, haveExtrasV2;
    var quietV4, quietV3, quietV2, cfgPath;

    // Resolve folder of this file; assumes the v4 files are alongside it.
    root = thisProcess.nowExecutingPath.dirname;
    work = root;

    // --- Load core v4 system files (order matters) ---
    cfgPath = (work ++ "/jit_config_v4.scd").standardizePath;
    ("[jit][DEMO v4] about to load config from: " ++ cfgPath).postln;

    thisProcess.interpreter.executeFile(cfgPath);
    thisProcess.interpreter.executeFile(work ++ "/jit_fxDefs_v4.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_core_v4.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_utils_v4.scd");

    // Crossfade (if you're using it) + patch (no server.sync)
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_crossfade_v4_clean.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_cf_adapter_v4.scd");

    // Bridge CF notify -> listener bus
    thisProcess.interpreter.executeFile(work ++ "/jit_notify_bridge_v4.scd");

    // GUI
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_core_v4.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_api_impl_v4.scd");

    // --- Try to load extras from v4; otherwise fall back to v3 or v2 ---
    extrasPathV4 = (work ++ "/jit_fxDefs_extras_v4.scd").standardizePath;
    extrasPathV3 = (work ++ "/jit_fxDefs_extras_v3.scd").standardizePath;
    extrasPathV2 = (work ++ "/jit_fxDefs_extras_v2.scd").standardizePath;

    haveExtrasV4 = PathName(extrasPathV4).isFile;
    haveExtrasV3 = PathName(extrasPathV3).isFile;
    haveExtrasV2 = PathName(extrasPathV2).isFile;

    haveExtrasV4.if({
        ("[jit] Loading extras from file (v4): " ++ extrasPathV4).postln;
        thisProcess.interpreter.executeFile(extrasPathV4);
    },{
        haveExtrasV3.if({
            ("[jit] Loading extras from file (v3 fallback): " ++ extrasPathV3).postln;
            thisProcess.interpreter.executeFile(extrasPathV3);
        },{
            haveExtrasV2.if({
                ("[jit] Loading extras from file (v2 fallback): " ++ extrasPathV2).postln;
                thisProcess.interpreter.executeFile(extrasPathV2);
            },{
                ("[jit] Extras file not found; defining extras inline.").postln;
                // Inline extras same as v3 fallback
            });
        });
    });

    // --- Session params ---
    ~numCh = 6;
    ~jitUseRealInput    = true;   // SoundIn(0 .. 5)
    ~jitUseSplayDownmix = true;   // Splay to stereo at destination
    ~sourceAmp   = 0.7;
    ~defaultAmp  = 0.8;
    ~jitFadeTime = 0.25;

    // --- Demo spec with obvious FX ---
    ~demoSpec1 = [
        \guitar,
        [\chopTrem, (id: \ch1, rate: 8, duty: 0.25, smooth: 0.003, mix: 1.0)],
        [\ringmod,  (id: \rm1, freq: 500, mix: 0.85)],
        [\slapback, (id: \sl1, time: 0.12, decay: 1.8, mix: 0.9,
                     damp: 3200, hp: 120, wobbleRate: 0.7, wobbleDepth: 0.002)],
        \destinationStereo
    ];

    // --- Build & play ---
    ~jitBuild.(~demoSpec1);
    ~jitPlay.();
    s.meter;

    // Load the quiet status LAST so it beats any wrappers
    quietV4 = (work ++ "/jit_quiet_status_v4.scd").standardizePath;
    quietV3 = (work ++ "/jit_quiet_status_v3.scd").standardizePath;
    quietV2 = (work ++ "/jit_quiet_status_v2.scd").standardizePath;
    if (PathName(quietV4).isFile) {
        thisProcess.interpreter.executeFile(quietV4);
    } {
        if (PathName(quietV3).isFile) {
            thisProcess.interpreter.executeFile(quietV3);
        } {
            if (PathName(quietV2).isFile) {
                thisProcess.interpreter.executeFile(quietV2);
            };
        };
    };

    // Optional: one-time silent status call (it returns an Event)
    (~jitStatus ? { ~jitStatus.() }).value;
});
)
