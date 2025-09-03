// jit_notify_bridge_v4.scd
// Bridge crossfade notifies to the same listener bus used by the GUI.
// No default arguments in arg list; defaults computed inside.
// Load AFTER: jit_chain_utils_v3.scd (+ any utils patch), and AFTER crossfade layer (+ patch) if you use CF.

(
///////////////////////////////
// Listener registry (idempotent)
///////////////////////////////
~jitListeners = ~jitListeners ? Array.new;

~jitAddListener = ~jitAddListener ? { |fn|
    (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) })
};

~jitRemoveListener = ~jitRemoveListener ? { |fn|
    ~jitListeners = ~jitListeners.reject(_ == fn)
};

///////////////////////////////
// Central notifier (GUI-safe via .defer)
///////////////////////////////
~jitNotify = ~jitNotify ? { |phase, payload|
    var arr, pay;
    // default payload to an empty Event if nil
    pay = payload ? ();
    arr = (~jitListeners ? Array.new);
    arr.do { |fn| { fn.value(phase, pay) }.defer };
    arr  // return listener array (handy for quick sanity checks)
};

///////////////////////////////
// Bridge the crossfade hook to ~jitNotify
///////////////////////////////
~jitOnRebuildNotify = ~jitOnRebuildNotify ? { |phase, payload|
    ~jitNotify.(phase, payload)
};
)
