
// jit_chainBuilder_core_v5.scd
// Core chain-building functions: build, play, free, and pure UGen maker

~jitBuild = { |spec|
    var ok, last, stages, isStereoDest, mustStereo, nInChannels;
    ok = true;
    // ... full function body omitted for brevity (use Martin's original code)
};

~jitPlay = {
    Ndef(\out).play(~outOffset);
};

~jitFree = {
    Ndef(\out).stop;   Ndef(\out).clear;
    Ndef(\chain).stop; Ndef(\chain).clear;
    ~jitClearState.();
};

~jitMakeChainFunc = ~jitMakeChainFunc ? { |spec|
    var ok, last, stages, isStereoDest, mustStereo, nInGuess, srcAmpDefault, destAmpDefault;
    var validate, makeSource, applyStages, makeDest;
    ok = true;
    // ... full function body omitted for brevity (use Martin's original code)
};

~jitBuildIntoChain = { |which, spec|
    var func;
    func = ~jitMakeChainFunc.(spec);
    func
};

~jitFreeHook = (~jitFreeHook ? { { ~jitFree.value }.forkIfNeeded; });
CmdPeriod.remove(~jitFreeHook);
CmdPeriod.add(~jitFreeHook);
