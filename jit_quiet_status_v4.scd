// jit_quiet_status_v4.scd
// MD 20250903 — Silent status reporter for JIT chain (v4)
// - Posts minimal info
// - Returns an Event with key runtime params
// - No GUI, no Ndef changes, caret-free, vars-first

(
var evt;

"[jit v4] Quiet status check".postln;

evt = (
    version: 4,
    spec: (~jitCurrentSpec ? nil),
    numCh: (~numCh ? 6),
    fadeTime: (~jitFadeTime ? 0.25),
    limiter: (~jitUseLimiter ? false),
    realInput: ((~jitUseRealInput ? false) == true),
    splayDownmix: ((~jitUseSplayDownmix ? true) == true)
);

// Post summary
("Spec: " ++ evt[\spec].asString).postln;
("numCh: " ++ evt[\numCh].asString
    ++ " | fadeTime: " ++ evt[\fadeTime].asString
    ++ " | limiter: " ++ evt[\limiter].asString
    ++ " | realInput: " ++ evt[\realInput].asString
    ++ " | splayDownmix: " ++ evt[\splayDownmix].asString).postln;

evt
)
