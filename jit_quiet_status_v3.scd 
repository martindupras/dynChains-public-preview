// jit_quiet_status_v3.scd  (hard-silent version)
// Load this LAST so it overrides any chatty wrappers or callers.
// Never posts; always returns a compact status Event.

(
~jitStatus = { |postIgnored = false|
    var cfEnabled, active, fade, tail, info;

    cfEnabled = ~jitCFEnabled ? false;
    active    = ~jitActiveChain ? \A;

    // fade/tail with robust nil-guards
    fade = if(~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }, {
        ~jitCF[\fadeTime]
    },{
        (~jitFadeTime ? 0.25)
    });

    tail = if(~jitCF.notNil and: { ~jitCF[\tailHold].notNil }, {
        ~jitCF[\tailHold]
    },{
        2.0
    });

    info = (
        cfEnabled:   cfEnabled,
        active:      active,
        fade:        fade,
        tail:        tail,
        nextPresent: (~jitNextSpec.notNil)
    );

    // No printing here — always silent, regardless of the 'postIgnored' arg.
    info
};
)
