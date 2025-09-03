// jit_session_hexSplay_demo_v3.scd
// MD 20250829-15:54 — 6ch BlackHole → Splay stereo, with loud demo FX (chop trem, slapback, ringmod)

/////////////////////////// 0) I/O and server reboot ///////////////////////////
(
s.options.inDevice  = "BlackHole 16ch";
s.options.outDevice = "MacBook Pro Speakers";
s.options.numInputBusChannels  = 6;
s.options.numOutputBusChannels = 2;
s.reboot;

s.waitForBoot({
    var root, work, extrasPathV3, extrasPathV2, haveExtrasV3, haveExtrasV2, quietV3, quietV2, cfgPath;

    // Resolve folder of this file; assumes the v3 files are alongside it.
    root = thisProcess.nowExecutingPath.dirname;

    // Working files live here
    work = root;

    // --- Load core v3 system files (order matters) ---

    cfgPath = (work ++ "/jit_config_v3.scd").standardizePath;
    ("[jit][DEMO] about to load config from: " ++ cfgPath).postln;

    thisProcess.interpreter.executeFile(cfgPath);

    // CHANGE 1: removed duplicate config load (kept the first one above)
    // thisProcess.interpreter.executeFile(work ++ "/jit_config_v3.scd");

    thisProcess.interpreter.executeFile(work ++ "/jit_fxDefs_v3.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_core_v3.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_utils_v3.scd");

    // CHANGE 2: utils patch shim no longer needed (merged into jit_chain_utils_v3.scd)
    // thisProcess.interpreter.executeFile(work ++ "/jit_chain_utils_v3_patch.scd");

    // Crossfade (if you're using it) + patch (no server.sync)
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_crossfade_v4_clean.scd");
    /* thisProcess.interpreter.executeFile(work ++ "/jit_chain_crossfade_v3_patch.scd"); */
	thisProcess.interpreter.executeFile(work ++ "/jit_cf_adapter_v3.scd");   // <-- NEW: wire CF into helpers


    // Bridge CF notify -> listener bus
    thisProcess.interpreter.executeFile(work ++ "/jit_notify_bridge_v3.scd");

    // GUI
    // thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_v3.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_core_v3.scd");

    // CHANGE 3: load the API implementation (not the temporary shim)
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_api_impl_v3.scd");

    // --- Try to load extras from v3; otherwise fall back to v2; otherwise define inline (load ONCE) ---
    extrasPathV3 = (work ++ "/jit_fxDefs_extras_v3.scd").standardizePath;
    extrasPathV2 = (work ++ "/jit_fxDefs_extras_v2.scd").standardizePath;
    haveExtrasV3 = PathName(extrasPathV3).isFile;
    haveExtrasV2 = PathName(extrasPathV2).isFile;

    haveExtrasV3.if({
        ("[jit] Loading extras from file (v3): " ++ extrasPathV3).postln;
        thisProcess.interpreter.executeFile(extrasPathV3);
    },{
        haveExtrasV2.if({
            ("[jit] Loading extras from file (v2 fallback): " ++ extrasPathV2).postln;
            thisProcess.interpreter.executeFile(extrasPathV2);
        },{
            ("[jit] Extras file not found; defining extras inline.").postln;

            // Ensure registries exist (usually set by jit_fxDefs_v2/jit_fxDefs_v3)
            ~fxBuilders   = (~fxBuilders   ? IdentityDictionary.new);
            ~argsOrEvent  = (~argsOrEvent  ? { |args| args ? () });

            // ---- Chopping Tremolo ----
            ~fxBuilders[\chopTrem] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var rateCtl, dutyCtl, smoothCtl, mixCtl, gate;
                    rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 8.0)).clip(0.1, 25.0);
                    dutyCtl   = NamedControl.kr((prefix ++ "_duty").asSymbol,   (a.at(\duty)   ? 0.25)).clip(0.01, 0.99);
                    smoothCtl = NamedControl.kr((prefix ++ "_smooth").asSymbol, (a.at(\smooth) ? 0.003)).clip(0.0, 0.05);
                    mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 1.0)).clip(0.0, 1.0);
                    gate = Lag.kr(LFPulse.kr(rateCtl, 0, dutyCtl), smoothCtl); // 0..1
                    XFade2.ar(in, in * gate, (mixCtl * 2) - 1)
                }
            };

            // ---- Slapback Echo ----
            ~fxBuilders[\slapback] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var timeCtl, decayCtl, mixCtl, dampCtl, hpCtl, wobRateCtl, wobDepthCtl;
                    var modTime, maxDelay, wet;
                    timeCtl     = NamedControl.kr((prefix ++ "_time").asSymbol,        (a.at(\time)        ? 0.12)).clip(0.03, 0.25);
                    decayCtl    = NamedControl.kr((prefix ++ "_decay").asSymbol,       (a.at(\decay)       ? 1.6)).clip(0.1, 4.0);
                    mixCtl      = NamedControl.kr((prefix ++ "_mix").asSymbol,         (a.at(\mix)         ? 0.9)).clip(0.0, 1.0);
                    dampCtl     = NamedControl.kr((prefix ++ "_damp").asSymbol,        (a.at(\damp)        ? 3500)).clip(500, 18000);
                    hpCtl       = NamedControl.kr((prefix ++ "_hp").asSymbol,          (a.at(\hp)          ? 120)).clip(20, 2000);
                    wobRateCtl  = NamedControl.kr((prefix ++ "_wobbleRate").asSymbol,  (a.at(\wobbleRate)  ? 0.7)).clip(0.0, 5.0);
                    wobDepthCtl = NamedControl.kr((prefix ++ "_wobbleDepth").asSymbol, (a.at(\wobbleDepth) ? 0.002)).clip(0.0, 0.02);

                    modTime  = SinOsc.kr(wobRateCtl).mulAdd(wobDepthCtl, timeCtl).clip(0.02, 0.35);
                    maxDelay = (timeCtl + wobDepthCtl + 0.02).clip(0.05, 0.6); // headroom for mod

                    wet = CombC.ar(in, maxDelay, modTime, decayCtl);
                    wet = HPF.ar(wet, hpCtl);
                    wet = LPF.ar(wet, dampCtl);
                    XFade2.ar(in, wet, (mixCtl * 2) - 1)
                }
            };

            // ---- Ring Modulator ----
            ~fxBuilders[\ringmod] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var freqCtl, mixCtl, carrier;
                    freqCtl = NamedControl.kr((prefix ++ "_freq").asSymbol, (a.at(\freq) ? 500)).clip(0.5, 8000);
                    mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol,  (a.at(\mix)  ? 0.85)).clip(0.0, 1.0);
                    carrier = (SinOsc.ar(freqCtl) ! in.numChannels);
                    XFade2.ar(in, in * carrier, (mixCtl * 2) - 1)
                }
            };
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
    quietV3 = (work ++ "/jit_quiet_status_v3.scd").standardizePath;
    quietV2 = (work ++ "/jit_quiet_status_v2.scd").standardizePath;
    if (PathName(quietV3).isFile) {
        thisProcess.interpreter.executeFile(quietV3);
    } {
        if (PathName(quietV2).isFile) { thisProcess.interpreter.executeFile(quietV2) };
    };

    // Optional: one-time silent status call (it returns an Event)
    (~jitStatus ? { ~jitStatus.() }).value;
});
)
