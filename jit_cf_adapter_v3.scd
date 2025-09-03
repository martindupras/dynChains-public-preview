// jit_cf_adapter_v3.scd  (corrected)
// MD 20250902


(
~jitCFAdapter = (~jitCFAdapter ? ()).putAll((
    buildInactive: { |spec|
        var inactive;
        inactive = ((~jitActiveChain ? \A) == \A).if(\B, \A);
        (~jitBuildIntoChain.isFunction).if({ ~jitBuildCF.(inactive, spec) });
    },

    switchNow: { |fade, tail|
        var target, ft, tl;
        ft = fade ?? { (~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25)) };
        tl = tail ?? { (~jitCF[\tailHold] ? 0.0) };
        target = ((~jitActiveChain ? \A) == \A).if(\B, \A);
        ~jitSetCrossfade.(ft, tl);
        ~jitStartCrossfadeTo.(target, ft, tl);   // DSP only; GUI happens in helper
    },

    switchIn: { |seconds, fade, tail|
        var d, ft, tl;
        d  = seconds.max(0);
        ft = fade ?? { (~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25)) };
        tl = tail ?? { (~jitCF[\tailHold] ? 0.0) };
        AppClock.sched(d, { ~jitCFSwitchNow.(ft, tl); nil });
    },

    activeSlot: { ~jitActiveChain ? \A }
));
)


/*(
~jitCFAdapter = (~jitCFAdapter ? ()).putAll((
    // Build the INACTIVE slot with 'spec' (does NOT switch).
    buildInactive: { |spec|
        var inactive;
        inactive = ((~jitActiveChain ? \A) == \A).if(\B, \A);

        // Only attempt per-slot build if available (pure preview still happens)
        (~jitBuildIntoChain.isFunction).if({
            ~jitBuildCF.(inactive, spec);
        },{
            nil
        });
    },

    // Trigger the audio crossfade NOW (no GUI/notify here by design).
    // GUI + bookkeeping are handled by ~jitCFSwitchNow (helper).
    switchNow: { |fade, tail|
        var target, ft, tl;
        ft = fade ?? { (~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25)) };
        tl = tail ?? { (~jitCF[\tailHold] ? 0.0) };
        target = ((~jitActiveChain ? \A) == \A).if(\B, \A);
        ~jitSetCrossfade.(ft, tl);
        ~jitStartCrossfadeTo.(target, ft, tl);
    },

    // Schedule the switch via the helper that handles GUI/notify + ~jitNextSpec reset.
    switchIn: { |seconds, fade, tail|
        var d, ft, tl;
        d  = seconds.max(0);
        ft = fade ?? { (~jitCF[\fadeTime] ? (~jitFadeTime ? 0.25)) };
        tl = tail ?? { (~jitCF[\tailHold] ? 0.0) };
        AppClock.sched(d, { ~jitCFSwitchNow.(ft, tl); nil });
    },

    // Report current active slot.
    activeSlot: { ~jitActiveChain ? \A }
));
)*/
