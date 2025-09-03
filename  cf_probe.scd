// cf_probe.scd
(
~cfA = [ \source,
    [\chopTrem, (id:\ch1, rate:5, depth:0.7)],
    [\slapback, (id:\sb1, time:0.14, mix:0.35)],
    \destination
];

~cfB = [ \source,
    [\flanger,  (id:\fl1, depth:0.6, rate:0.3)],
    [\ringmod,  (id:\rm1, freq:140, mix:0.5)],
    \destination
];

// enable CF if needed
(~jitSetCrossfade.notNil).if({ ~jitSetCrossfade.(fade: 0.25, tail: 1.5) });

// run one cycle A -> B -> A
~jitBuildCF.notNil.if({
    ~jitBuildCF.(~cfA);
    AppClock.sched(4.0, {
        ~jitBuildCF.(~cfB);
        AppClock.sched(4.0, { ~jitBuildCF.(~cfA); nil });
    });
}, {
    "[probe] ~jitBuildCF missing; skipping crossfade test.".warn;
});
)
