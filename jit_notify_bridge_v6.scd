// jit_notify_bridge_v6.scd
// Notification bridge for v6: connects chain/crossfade engine events to listeners (GUI, scripts, etc).
// Load after your chain core, utils, and crossfade adapter/engine.

(
    // --- Listener registry ---
    ~jitListeners = (~jitListeners ? Array.new);

    // Add a listener (idempotent). Returns a disposer function you can call to remove it.
    ~jitAddListener = { |fn|
        (fn.isFunction).if({
            (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) });
        });
        { ~jitRemoveListener.(fn) } // disposer
    };

    // Remove a specific listener
    ~jitRemoveListener = { |fn|
        ~jitListeners = (~jitListeners ? Array.new).reject(_ == fn);
    };

    // Clear all listeners; returns how many were removed (useful in Cmd-. hooks)
    ~jitClearListeners = {
        var n = (~jitListeners ? Array.new).size;
        ~jitListeners = Array.new;
        n
    };

    // --- Notify all listeners of an event (GUI-safe via defer) ---
    ~jitNotify = { |phase, payload = nil|
        var snapshot;
        snapshot = (~jitListeners ? Array.new).copy; // avoid mutation surprises during iteration
        snapshot.do { |fn|
            if(fn.isFunction) { { fn.value(phase, payload) }.defer };
        };
    };

    // --- Throttling utilities (optional but recommended) ---
    // Creates a callable that runs at most once every `minInterval` seconds, coalescing calls.
    ~jitMakeThrottler = { |minInterval = 0.12, fn|
        var nextTime = 0.0, pending = false;
        {
            var now = AppClock.seconds;
            if(now >= nextTime) {
                nextTime = now + minInterval;
                fn.value;
            }{
                if(pending.not) {
                    pending = true;
                    AppClock.sched((nextTime - now).max(0.0), {
                        pending = false;
                        nextTime = AppClock.seconds + minInterval;
                        fn.value;
                        nil
                    });
                };
            };
        }
    };

    // Provide a default GUI refresher if not already defined and refresh API is present
    (~jitGuiRefreshOnce.isNil and: { ~jitGui_refresh.isFunction }).if({
        ~jitGuiRefreshOnce = ~jitMakeThrottler.(0.12, { ~jitGui_refresh.() });
    });

    // Throttled notify per phase (useful for frequent updates like meters)
    ~jitNotifyThrottlers = (~jitNotifyThrottlers ? IdentityDictionary.new);
    ~jitNotifyThrottled = { |phase, payload = nil, interval = 0.1|
        var key, thr;
        key = phase.asSymbol;
        thr = ~jitNotifyThrottlers[key];
        if(thr.isNil) {
            thr = ~jitMakeThrottler.(interval, { ~jitNotify.(key, payload) });
            ~jitNotifyThrottlers[key] = thr;
        };
        thr.value;
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
