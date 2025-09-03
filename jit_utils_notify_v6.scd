// jit_utils_notify_v6.scd
// Listener registry, notification, status, and GUI helpers.

(
    ~jitListeners = ~jitListeners ? Array.new;
    ~jitAddListener = { |fn| (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) }) };
    ~jitRemoveListener = { |fn| ~jitListeners = ~jitListeners.reject(_ == fn) };

    ~jitNotify = { |phase, payload = nil|
        var arr = (~jitListeners ? Array.new);
        arr.do { |fn| { fn.value(phase, payload) }.defer };
    };
    ~jitNotifyWillBuild  = { |spec| ~jitNotify.(\willBuild, (spec: spec)) };
    ~jitNotifyDidBuild   = { |spec| ~jitNotify.(\didBuild,  (cur: spec, next: ~jitNextSpec)) };
    ~jitNotifyWillSwitch = { |from, to, fade, tail|
        var f = fade ? (~jitFadeTime ? 0.25);
        var t = tail ? 0.0;
        ~jitNotify.(\willSwitch, (from: from, to: to, fade: f, tail: t))
    };
    ~jitNotifyDidSwitch  = { |active, spec| ~jitNotify.(\didSwitch, (active: active, spec: spec)) };

    ~jitStatus = {
        ("--- JIT Status ---").postln;
        ("Spec: " ++ (~jitCurrentSpec ? "nil").asString).postln;
        ("Stage Index Nodes: " ++ (~jitStageIndexNodes ? []).asString).postln;
        ("ID Map: " ++ (~jitStageIdInfo ? IdentityDictionary.new).asString).postln;
        ("Ndef(\\chain) channels: " ++ Ndef(\chain).numChannels).postln;
        ("Ndef(\\out)   channels: " ++ Ndef(\out).numChannels).postln;
        ("fadeTime: " ++ ~jitFadeTime.asString
            ++ " | numCh: " ++ ~numCh.asString
            ++ " | outOffset: " ++ ~outOffset.asString
            ++ " | useRealInput: " ++ ((~jitUseRealInput ? false) == true).asString
            ++ " | splayDownmix: " ++ (~jitUseSplayDownmix ? false).asString).postln;
        ("-------------------").postln;
    };

    ~jitDebugDump = {
        ("[jit] index nodes: " ++ (~jitStageIndexNodes ? []).asString).postln;
        ("[jit] id info: " ++ (~jitStageIdInfo ? IdentityDictionary.new).asString).postln;
    };
)