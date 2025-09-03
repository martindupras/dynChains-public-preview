(
// Same loading block as above… only change is the source proxy:

~numCh = 6; ~jitUseRealInput = false; ~jitUseSplayDownmix = true; ~jitFadeTime = 0.25;

~rootPath = { var p = thisProcess.nowExecutingPath; p = p.notNil.if({ PathName(p).pathOnly }, { thisProcess.getcwd }) }.value;
~joinPath = { |*parts| parts.reject(_.isNil).joinPaths };
~tryLoad  = { |fileName| var full = ~joinPath.(~rootPath, fileName); (File.exists(full)).if({ full.load; ("[load] " ++ fileName).postln; true },{ ("[WARN] missing: " ++ full).warn; false }) };

Server.default = s = Server.local;
s.options.numInputBusChannels = 2;  // builtin
s.options.numOutputBusChannels = 2;
s.options.memSize = 2.pow(19);

~loadAll = {
    ~tryLoad.("jit_config_v2.scd");
    ~tryLoad.("jit_fxDefs_v2.scd");
    ~tryLoad.("jit_fxDefs_extras_v2.scd");
    ~tryLoad.("jit_chain_core_v2.scd");
    ~tryLoad.("jit_chain_utils_v2.scd");
    ~tryLoad.("jit_chain_utils_v2_patch.scd");  // optional
    ~tryLoad.("jit_chain_gui_v2.scd");          // GUI
};

~afterBoot = {
    Ndef.defaultFadeTime = ~jitFadeTime ? 0.25;

    // Synthetic 6ch source for testing
    Ndef(\src).source = {
        var sig;
        sig = PinkNoise.ar(0.15)! ~numCh;
        sig
    };
    Ndef(\src).fadeTime = ~jitFadeTime ? 0.25;

    ~demoSpec = [
        \source,
        [\chopTrem, (id: \ch1, rate: 6, depth: 0.8)],
        [\ringmod,  (id: \rm1, freq: 160, mix: 0.4)],
        [\slapback, (id: \sb1, time: 0.14, mix: 0.35)],
        \destination
    ];

    (~jitBuildCF.notNil).if({ ~jitBuildCF.(~demoSpec) }, { ~jitBuild.(~demoSpec) });
    (~jitPlay.notNil).if({ ~jitPlay.() });
    (~jitGuiShow.notNil).if({ ~jitGuiShow.(useListeners: true) });
};

~loadAll.();
s.waitForBoot({ ~afterBoot.() });
s.boot;
)
