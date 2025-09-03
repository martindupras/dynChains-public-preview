// jit_quiet_status_v2.scd  (hard-silent version)
// Load this LAST so it overrides any chatty wrappers or callers.
// Never posts; always returns a compact status Event.

(
~jitStatus = { |postIgnored = false|
    var cfEnabled, active, fade, tail, info;

    cfEnabled = ~jitCFEnabled ? false;
    active    = ~jitActiveChain ? \A;

    // fade/tail fallbacks if ~jitCF is missing
    fade = (~jitCF ? (~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25)) : (~jitFadeTime ? 0.25));
    tail = (~jitCF ? (~jitCF[\tailHold] ? 2.0) : 2.0);

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
