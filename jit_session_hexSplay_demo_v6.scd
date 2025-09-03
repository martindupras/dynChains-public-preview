// =============================
// jit_session_hexSplay_demo_v6.scd
// Hexaphonic guitar signal chain demo (6ch BlackHole → Splay stereo, with loud demo FX)
// Refactored for clarity and organization
// =============================

(
// ---- 1. Audio I/O and Server Setup ----
s.options.inDevice  = "BlackHole 16ch";        // 6ch hex guitar input
s.options.outDevice = "MacBook Pro Speakers";  // Stereo output
s.options.numInputBusChannels  = 6;
s.options.numOutputBusChannels = 2;
s.reboot;

s.waitForBoot({
    // ---- Variable Declarations ----
    var root, work, quietV3, quietV2, extrasPathV3, extrasPathV2, cfgPath, loadFiles;

    // ---- 2. Path Definitions ----
    root = thisProcess.nowExecutingPath.dirname;
    work = root;

    // ---- 3. Helper: Load Files in Order ----
    loadFiles = { |files|
        files.do { |fname|
            var fpath = (work ++ "/" ++ fname).standardizePath;
            ("[jit][DEMO] loading: " ++ fpath).postln;
            thisProcess.interpreter.executeFile(fpath);
        }
    };

    // ---- 4. Load Core System Files ----
    cfgPath = (work ++ "/jit_config_v6.scd").standardizePath;
    ("[jit][DEMO] loading config: " ++ cfgPath).postln;
    thisProcess.interpreter.executeFile(cfgPath);

    loadFiles.([
        "jit_fxDefs_v6.scd",
        "jit_chain_core_v6
.scd",
        "jit_chain_utils_v6.scd",
        "jit_chain_crossfade_v4_clean.scd",
        "jit_cf_adapter_v3.scd",
        "jit_notify_bridge_v3.scd",
        "jit_chain_gui_core_v3.scd",
        "jit_chain_gui_api_impl_v3.scd"
    ]);

    // ---- 5. Load Extra FX Definitions (v3, v2, or fallback inline) ----
    extrasPathV3 = (work ++ "/jit_fxDefs_extras_v3.scd").standardizePath;
    extrasPathV2 = (work ++ "/jit_fxDefs_extras_v2.scd").standardizePath;

    if (PathName(extrasPathV3).isFile) {
        ("[jit] Loading extras from file (v3): " ++ extrasPathV3).postln;
        thisProcess.interpreter.executeFile(extrasPathV3);
    } {
        if (PathName(extrasPathV2).isFile) {
            ("[jit] Loading extras from file (v2 fallback): " ++ extrasPathV2).postln;
            thisProcess.interpreter.executeFile(extrasPathV2);
        } {
            ("[jit] Extras file not found; defining extras inline.").postln;

            // Ensure registries exist
            ~fxBuilders   = (~fxBuilders   ? IdentityDictionary.new);
            ~argsOrEvent  = (~argsOrEvent  ? { |args| args ? () });

            // ---- Chopping Tremolo ----
            ~fxBuilders[\chopTrem] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var rateCtl   = NamedControl.kr((prefix ++ "_rate").asSymbol,   (a.at(\rate)   ? 8.0)).clip(0.1, 25.0);
                    var dutyCtl   = NamedControl.kr((prefix ++ "_duty").asSymbol,   (a.at(\duty)   ? 0.25)).clip(0.01, 0.99);
                    var smoothCtl = NamedControl.kr((prefix ++ "_smooth").asSymbol, (a.at(\smooth) ? 0.003)).clip(0.0, 0.05);
                    var mixCtl    = NamedControl.kr((prefix ++ "_mix").asSymbol,    (a.at(\mix)    ? 1.0)).clip(0.0, 1.0);
                    var gate = Lag.kr(LFPulse.kr(rateCtl, 0, dutyCtl), smoothCtl); // 0..1
                    XFade2.ar(in, in * gate, (mixCtl * 2) - 1)
                }
            };

            // ---- Slapback Echo ----
            ~fxBuilders[\slapback] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var timeCtl     = NamedControl.kr((prefix ++ "_time").asSymbol,        (a.at(\time)        ? 0.12)).clip(0.03, 0.25);
                    var decayCtl    = NamedControl.kr((prefix ++ "_decay").asSymbol,       (a.at(\decay)       ? 1.6)).clip(0.1, 4.0);
                    var mixCtl      = NamedControl.kr((prefix ++ "_mix").asSymbol,         (a.at(\mix)         ? 0.9)).clip(0.0, 1.0);
                    var dampCtl     = NamedControl.kr((prefix ++ "_damp").asSymbol,        (a.at(\damp)        ? 3500)).clip(500, 18000);
                    var hpCtl       = NamedControl.kr((prefix ++ "_hp").asSymbol,          (a.at(\hp)          ? 120)).clip(20, 2000);
                    var wobRateCtl  = NamedControl.kr((prefix ++ "_wobbleRate").asSymbol,  (a.at(\wobbleRate)  ? 0.7)).clip(0.0, 5.0);
                    var wobDepthCtl = NamedControl.kr((prefix ++ "_wobbleDepth").asSymbol, (a.at(\wobbleDepth) ? 0.002)).clip(0.0, 0.02);

                    var modTime  = SinOsc.kr(wobRateCtl).mulAdd(wobDepthCtl, timeCtl).clip(0.02, 0.35);
                    var maxDelay = (timeCtl + wobDepthCtl + 0.02).clip(0.05, 0.6); // headroom for mod

                    var wet = CombC.ar(in, maxDelay, modTime, decayCtl);
                    wet = HPF.ar(wet, hpCtl);
                    wet = LPF.ar(wet, dampCtl);
                    XFade2.ar(in, wet, (mixCtl * 2) - 1)
                }
            };

            // ---- Ring Modulator ----
            ~fxBuilders[\ringmod] = { |prefix, args = nil|
                var a = ~argsOrEvent.(args);
                { |in|
                    var freqCtl = NamedControl.kr((prefix ++ "_freq").asSymbol, (a.at(\freq) ? 500)).clip(0.5, 8000);
                    var mixCtl  = NamedControl.kr((prefix ++ "_mix").asSymbol,  (a.at(\mix)  ? 0.85)).clip(0.0, 1.0);
                    var carrier = (SinOsc.ar(freqCtl) ! in.numChannels);
                    XFade2.ar(in, in * carrier, (mixCtl * 2) - 1)
                }
            };
        }
    };

    // ---- 6. Session Parameters ----
    ~sessionParams = (
        numCh: 6,
        useRealInput: true,      // SoundIn(0..5)
        useSplayDownmix: true,   // Splay to stereo at destination
        sourceAmp: 0.7,
        defaultAmp: 0.8,
        fadeTime: 0.25
    );

    // ---- 7. Demo Chain Specification ----
    // Hex guitar input → Chop Trem → Ringmod → Slapback → Stereo output
    ~demoChainSpec = [
        \guitar,
        [\chopTrem, (id: \ch1, rate: 8, duty: 0.25, smooth: 0.003, mix: 1.0)],
        [\ringmod,  (id: \rm1, freq: 500, mix: 0.85)],
        [\slapback, (id: \sl1, time: 0.12, decay: 1.8, mix: 0.9,
                     damp: 3200, hp: 120, wobbleRate: 0.7, wobbleDepth: 0.002)],
        \destinationStereo
    ];

    // ---- 8. Build and Play Signal Chain ----
    ~jitBuild.(~demoChainSpec);
    ~jitPlay.();
    s.meter;

    // ---- 9. Load Quiet Status File (optional silencing) ----
    quietV3 = (work ++ "/jit_quiet_status_v3.scd").standardizePath;
    quietV2 = (work ++ "/jit_quiet_status_v2.scd").standardizePath;
    if (PathName(quietV3).isFile) {
        thisProcess.interpreter.executeFile(quietV3);
    } {
        if (PathName(quietV2).isFile) { thisProcess.interpreter.executeFile(quietV2) };
    };

    // ---- 10. Display Final Status ----
    (~jitStatus ? { ~jitStatus.() }).value;
});
)