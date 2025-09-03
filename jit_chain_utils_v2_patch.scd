// jit_chain_utils_v2_patch.scd
// Patch: HTML entities fixed, listener API formalized, removed eager broadcast at load
// Load this AFTER your existing jit_chain_utils_v2.scd to override the few defs below
(
// ----- FIX 1: Listener registry (no eager broadcast on load) -----
~jitListeners = ~jitListeners ? Array.new;
~jitAddListener = { |fn| (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) }) };
~jitRemoveListener = { |fn| ~jitListeners = ~jitListeners.reject(_ == fn) };

// Central notifier; GUI callers typically defer; we also .defer here for safety
~jitNotify = { |phase, payload = nil|
    var arr;
    arr = (~jitListeners ? Array.new);
    arr.do { |fn| { fn.value(phase, payload) }.defer };
};

// Convenience wrappers (optional)
~jitNotifyWillBuild  = { |spec| ~jitNotify.(\willBuild, (spec: spec)) };
~jitNotifyDidBuild   = { |spec| ~jitNotify.(\didBuild,  (cur: spec, next: ~jitNextSpec)) };
/*~jitNotifyWillSwitch = { |from, to, fade = ~jitFadeTime, tail = 0.0|
    ~jitNotify.(\willSwitch, (from: from, to: to, fade: fade, tail: tail))
};*/
~jitNotifyWillSwitch = { |from, to, fade, tail|
    var f, t;
    f = fade ? (~jitFadeTime ? 0.25);
    t = tail ? 0.0;
    ~jitNotify.(\willSwitch, (from: from, to: to, fade: f, tail: t))
};

~jitNotifyDidSwitch  = { |active, spec| ~jitNotify.(\didSwitch, (active: active, spec: spec)) };

// ----- FIX 2: Array helper with real comparison operators (no HTML entities) -----
~jitArrayRemoveAt = { |arr, index|
    var n, idx;
    n = arr.size;
    (n <= 0).if({ [] }, {
        idx = index.clip(0, n - 1);
        (idx == 0).if({
            (n > 1).if({ arr.copyRange(1, n - 1) }, { [] })
        },{
            (idx == (n - 1)).if({
                arr.copyRange(0, n - 2)
            },{
                arr.copyRange(0, idx - 1) ++ arr.copyRange(idx + 1, n - 1)
            })
        })
    })
};

// ----- FIX 3: Spec utilities with real comparisons -----
~jitSpecStages = { |spec|
    var stages;
    stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
    stages
};

// No change in ~jitSpecWithStages

// ----- FIX 4: Stage info bounds check with real ops -----
~jitGetStageInfo = { |which|
    which.isNumber.if({
        var slot;
        slot = which.asInteger;
        if((slot < 0) or: { slot >= (~jitStageIndexNodes ? []).size }) {
            nil
        }{
            (slot: slot, prefix: ((~jitStageIndexNodes ? [])[slot] ?? { ("fx" ++ slot) }).asString)
        }
    },{
        ~jitStageIdInfo[which]
    })
};
)
