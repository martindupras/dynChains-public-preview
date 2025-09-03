// jit_notify_bridge_v6.scd
// Notification bridge for v6: connects chain/crossfade engine events to listeners (GUI, scripts, etc).
// Load after your chain core, utils, and crossfade adapter/engine.

(
    // --- Listener registry ---
    ~jitListeners = ~jitListeners ? Array.new;

    ~jitAddListener = { |fn|
        (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) });
    };

    ~jitRemoveListener = { |fn|
        ~jitListeners = ~jitListeners.reject(_ == fn);
    };

    // --- Notify all listeners of event ---
    ~jitNotify = { |phase, payload = nil|
        var arr;
        arr = (~jitListeners ? Array.new);
        arr.do { |fn| { fn.value(phase, payload) }.defer };
    };

    // --- Event shorthands ---
    ~jitNotifyWillBuild  = { |spec| ~jitNotify.(\willBuild, (spec: spec)) };
    ~jitNotifyDidBuild   = { |spec| ~jitNotify.(\didBuild,  (cur: spec, next: ~jitNextSpec)) };
    ~jitNotifyWillSwitch = { |from, to, fade, tail|
        var f, t;
        f = fade ? (~jitFadeTime ? 0.25);
        t = tail ? 0.0;
        ~jitNotify.(\willSwitch, (from: from, to: to, fade: f, tail: t));
    };
    ~jitNotifyDidSwitch  = { |active, spec| ~jitNotify.(\didSwitch, (active: active, spec: spec)) };
)