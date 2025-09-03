// jit_demo_chains_v3.scd
// MD 20250902-1303

// Contains examples of chains to build.

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
 ~jitBuildAndNotify.(~demoSpec_stutterSpring); ~jitPlay.(); s.meter;
)


(
~demoSpec_metalDub = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 1100, mix: 1.0)],      // metallic buzz
    [\delay,    (id:\d1,  time: 0.32, feedback: 0.7, mix: 0.8)],  // long echoes
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_metalDub); ~jitPlay.(); s.meter;
)

(
~demoSpec_swirl = [
    \guitar,
    [\flanger,  (id:\fl1, rate: 0.08, depth: 0.006, delay: 0.004, mix: 0.9)],
    [\slapback, (id:\sl1, time: 0.13, decay: 1.6, mix: 0.8, damp: 4000, hp: 100, wobbleRate: 0.3, wobbleDepth: 0.001)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_swirl); ~jitPlay.(); s.meter;
)

(
~demoSpec_fastStutter = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 20, duty: 0.4, smooth: 0.000, mix: 1.0)],
    [\delay,    (id:\d1,  time: 0.09, feedback: 0.55, mix: 0.7)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_fastStutter); ~jitPlay.(); s.meter;
)

(
~demoSpec_grooveMetal = [
    \guitar,
    [\tremolo,  (id:\tr1, rate: 5.0, depth: 0.7, phase: 0.0)],
    [\ringmod,  (id:\rm1, freq: 280, mix: 0.7)],   // AM wobble
    [\slapback, (id:\sl1, time: 0.10, decay: 1.4, mix: 0.85, damp: 3500, hp: 120, wobbleRate: 0.6, wobbleDepth: 0.002)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_grooveMetal); ~jitPlay.(); s.meter;
)

(
~demoSpec_dubSpace = [
    \guitar,
    [\delay,    (id:\d1, time: 0.38, feedback: 0.82, mix: 0.85)],
    [\slapback, (id:\sl1, time: 0.12, decay: 2.2, mix: 0.9, damp: 2200, hp: 90, wobbleRate: 0.5, wobbleDepth: 0.003)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_dubSpace); ~jitPlay.(); s.meter;
)

(
~demoSpec_ringSaw = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 1800, mix: 0.9)],
    [\flanger,  (id:\fl1, rate: 0.2, depth: 0.004, delay: 0.003, mix: 0.5)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_ringSaw); ~jitPlay.(); s.meter;
)

(
~demoSpec_gateDelay = [
    \guitar,
    [\chopTrem, (id:\ch1, rate: 7, duty: 0.2, smooth: 0.002, mix: 1.0)],
    [\delay,    (id:\d1,  time: 0.18, feedback: 0.65, mix: 0.8)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_gateDelay); ~jitPlay.(); s.meter;
)

(
~demoSpec_subAM = [
    \guitar,
    [\ringmod,  (id:\rm1, freq: 35, mix: 0.9)],   // trem-like heavy wobble
    [\slapback, (id:\sl1, time: 0.14, decay: 1.8, mix: 0.9, damp: 3200, hp: 100, wobbleRate: 0.7, wobbleDepth: 0.002)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_subAM); ~jitPlay.(); s.meter;
)


(
~demoSpec_moveStack = [
    \guitar,
    [\tremolo, (id:\tr1, rate: 3.2, depth: 0.5, phase: 0.0)],
    [\flanger, (id:\fl1, rate: 0.1, depth: 0.005, delay: 0.004, mix: 0.7)],
    [\delay,   (id:\d1,  time: 0.22, feedback: 0.55, mix: 0.6)],
    \destinationStereo
];
 ~jitBuildAndNotify.(~demoSpec_moveStack); ~jitPlay.(); s.meter;
"jit_quiet_status_v2.scd".loadRelative;  // must be after all other loads

)