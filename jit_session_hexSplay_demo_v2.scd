// jit_session_hexSplay_demo_v2.scd -- WORKING
// MD 20250829-15:54 — 6ch BlackHole → Splay stereo, with loud demo FX (chop trem, slapback, ringmod)
// This session tries to load jit_fxDefs_extras_v2.scd if present; otherwise it defines extras inline.

/////////////////////////// 0) I/O and server reboot ///////////////////////////
(
s.options.inDevice  = "BlackHole 16ch";
s.options.outDevice = "MacBook Pro Speakers";
s.options.numInputBusChannels  = 6;
s.options.numOutputBusChannels = 2;
s.reboot;
)

///////////////////// 1) On boot: load core + extras + run /////////////////////
(
s.waitForBoot({
    var root, work, extrasPath, haveExtras;

    // Resolve folder of this file; assumes the v2 files are alongside it.
    root = thisProcess.nowExecutingPath.dirname;

    // Working files live here
    work = root;

    // --- Load core v2 system files (order matters) ---
    thisProcess.interpreter.executeFile(work ++ "/jit_config_v2.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_fxDefs_v2.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_core_v2.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_utils_v2.scd");

    // Optional patch(es)
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_utils_v2_patch.scd");

    // Crossfade (if you're using it) + patch (no server.sync)
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_crossfade_v2.scd");
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_crossfade_v2_patch.scd");

    // Bridge CF notify -> listener bus
    thisProcess.interpreter.executeFile(work ++ "/jit_notify_bridge_v2.scd");

    // GUI
    thisProcess.interpreter.executeFile(work ++ "/jit_chain_gui_v2.scd");

    // --- Try to load extras from file; otherwise define them inline (load ONCE) ---
    extrasPath = (work ++ "/jit_fxDefs_extras_v2.scd").standardizePath;
    haveExtras = PathName(extrasPath).isFile;

    haveExtras.if({
        ("[jit] Loading extras from file: " ++ extrasPath).postln;
        thisProcess.interpreter.executeFile(extrasPath);
    },{
        ("[jit] Extras file not found; defining extras inline.").postln;

        // Ensure registries exist (usually set by jit_fxDefs_v2)
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
        [\chopTrem, (id:\ch1, rate: 8, duty: 0.25, smooth: 0.003, mix: 1.0)],
        [\ringmod,  (id:\rm1, freq: 500, mix: 0.85)],
        [\slapback, (id:\sl1, time: 0.12, decay: 1.8, mix: 0.9,
                     damp: 3200, hp: 120, wobbleRate: 0.7, wobbleDepth: 0.002)],
        \destinationStereo
    ];

    // --- Build & play ---
    ~jitBuild.(~demoSpec1);
    ~jitPlay.();
    s.meter;

    // Load the quiet status LAST so it beats any wrappers
    thisProcess.interpreter.executeFile(work ++ "/jit_quiet_status_v2.scd");

    // Optional: one-time silent status call (it returns an Event)
    (~jitStatus ? { ~jitStatus.() }).value;
});
)


//==========


///////////////////// 2) Cleanup helper (run when done) ////////////////////////
(
~jitFree.();   // stops & clears Ndef(\out) and Ndef(\chain), resets state
)



// DIFFERENT SIGNAL CHAINS TO TRY:
(
~demoSpec_stutterSpring = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 10, duty: 0.20, smooth: 0.002, mix: 1.0)],
    [\slapback, (id:\sl1, time: 0.11, decay: 2.2, mix: 1.0, damp: 3000, hp: 120, wobbleRate: 0.7, wobbleDepth: 0.003)],
    \destinationStereo
];
~jitBuild.(~demoSpec_stutterSpring); ~jitPlay.(); s.meter;
)


(
~demoSpec_metalDub = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 1100, mix: 1.0)],      // metallic buzz
    [\delay,    (id:\d1,  time: 0.32, feedback: 0.7, mix: 0.8)],  // long echoes
    \destinationStereo
];
~jitBuild.(~demoSpec_metalDub); ~jitPlay.(); s.meter;
)

(
~demoSpec_swirl = [
    \guitar,
    [\flanger,  (id:\fl1, rate: 0.08, depth: 0.006, delay: 0.004, mix: 0.9)],
    [\slapback, (id:\sl1, time: 0.13, decay: 1.6, mix: 0.8, damp: 4000, hp: 100, wobbleRate: 0.3, wobbleDepth: 0.001)],
    \destinationStereo
];
~jitBuild.(~demoSpec_swirl); ~jitPlay.(); s.meter;
)

(
~demoSpec_fastStutter = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 20, duty: 0.4, smooth: 0.000, mix: 1.0)],
    [\delay,    (id:\d1,  time: 0.09, feedback: 0.55, mix: 0.7)],
    \destinationStereo
];
~jitBuild.(~demoSpec_fastStutter); ~jitPlay.(); s.meter;
)

(
~demoSpec_grooveMetal = [
    \guitar,
    [\tremolo,  (id:\tr1, rate: 5.0, depth: 0.7, phase: 0.0)],
    [\ringmod,  (id:\rm1, freq: 280, mix: 0.7)],   // AM wobble
    [\slapback, (id:\sl1, time: 0.10, decay: 1.4, mix: 0.85, damp: 3500, hp: 120, wobbleRate: 0.6, wobbleDepth: 0.002)],
    \destinationStereo
];
~jitBuild.(~demoSpec_grooveMetal); ~jitPlay.(); s.meter;
)

(
~demoSpec_dubSpace = [
    \guitar,
    [\delay,    (id:\d1, time: 0.38, feedback: 0.82, mix: 0.85)],
    [\slapback, (id:\sl1, time: 0.12, decay: 2.2, mix: 0.9, damp: 2200, hp: 90, wobbleRate: 0.5, wobbleDepth: 0.003)],
    \destinationStereo
];
~jitBuild.(~demoSpec_dubSpace); ~jitPlay.(); s.meter;
)

(
~demoSpec_ringSaw = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 1800, mix: 0.9)],
    [\flanger,  (id:\fl1, rate: 0.2, depth: 0.004, delay: 0.003, mix: 0.5)],
    \destinationStereo
];
~jitBuild.(~demoSpec_ringSaw); ~jitPlay.(); s.meter;
)

(
~demoSpec_gateDelay = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 7, duty: 0.2, smooth: 0.002, mix: 1.0)],
    [\delay,    (id:\d1,  time: 0.18, feedback: 0.65, mix: 0.8)],
    \destinationStereo
];
~jitBuild.(~demoSpec_gateDelay); ~jitPlay.(); s.meter;
)

(
~demoSpec_subAM = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 35, mix: 0.9)],   // trem-like heavy wobble
    [\slapback, (id:\sl1, time: 0.14, decay: 1.8, mix: 0.9, damp: 3200, hp: 100, wobbleRate: 0.7, wobbleDepth: 0.002)],
    \destinationStereo
];
~jitBuild.(~demoSpec_subAM); ~jitPlay.(); s.meter;
)


(
~demoSpec_moveStack = [
    \guitar,
    [\tremolo, (id:\tr1, rate: 3.2, depth: 0.5, phase: 0.0)],
    [\flanger, (id:\fl1, rate: 0.1, depth: 0.005, delay: 0.004, mix: 0.7)],
    [\delay,   (id:\d1,  time: 0.22, feedback: 0.55, mix: 0.6)],
    \destinationStereo
];
~jitBuild.(~demoSpec_moveStack); ~jitPlay.(); s.meter;
"jit_quiet_status_v2.scd".loadRelative;  // must be after all other loads

)

