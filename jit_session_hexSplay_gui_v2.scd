// jit_session_hexSplay_gui_v2.scd
// One-shot loader for v2 + GUI
// - macOS: input "BlackHole 16ch" (use SoundIn 0..5), output "MacBook Pro Speakers"
// - Loads v2 stack, applies optional utils patch & GUI, builds a demo spec, and plays.

(
///////////////////////////////
// 0) Session toggles (yours) //
///////////////////////////////
~numCh              = 6;        // 6-channel source
~jitUseRealInput    = true;     // read SoundIn
~jitUseSplayDownmix = true;     // Splay → stereo
~jitFadeTime        = 0.25;     // NodeProxy fade

//////////////////////////////////////////////
// 1) Resolve root folder (robust pathing)  //
//////////////////////////////////////////////
~rootPath = {
    var p;
    p = thisProcess.nowExecutingPath;
    p = p.notNil.if({ PathName(p).pathOnly }, { thisProcess.getcwd });
}.value;

// Simple 2-arg join (SC Functions don’t support varargs *parts)
~joinPath = { |base, name| base +/+ name };

~tryLoad = { |fileName|
    var full;
    full = ~joinPath.(~rootPath, fileName);
    (File.exists(full)).if({
        full.load;
        ("[load] " ++ fileName).postln;
        true
    },{
        ("[WARN] missing: " ++ full).warn;
        false
    })
};

//////////////////////////////////////////////
// 2) Configure server (macOS) and boot     //
//////////////////////////////////////////////
Server.default = s = Server.local;
s.options.inDevice_("BlackHole 16ch");
s.options.outDevice_("MacBook Pro Speakers");
s.options.numInputBusChannels  = 16;   // BlackHole 16ch
s.options.numOutputBusChannels = 2;    // stereo outs
s.options.memSize = 2.pow(19);         // headroom

////////////////////////////////////////////////////////
// 3) Load stack: config → fx → core → utils → patch → GUI
////////////////////////////////////////////////////////
~loadAll = {
    ~tryLoad.("jit_config_v2.scd");
    ~tryLoad.("jit_fxDefs_v2.scd");
    ~tryLoad.("jit_fxDefs_extras_v2.scd");
    ~tryLoad.("jit_chain_core_v2.scd");
    ~tryLoad.("jit_chain_utils_v2.scd");

    // Optional: crossfade layer (harmless if absent)
    ~tryLoad.("jit_chain_crossfade_v2.scd");
    ~tryLoad.("jit_chain_crossfade_v2_patch.scd"); // if you saved the no-sync patch

    // Optional: utils patch (listener API + HTML entity fixes)
    ~tryLoad.("jit_chain_utils_v2_patch.scd");

    // Production GUI (auto-follows ~jitCurrentSpec / ~jitNextSpec)
    ~tryLoad.("jit_chain_gui_v2.scd");
};

//////////////////////////////////////////////
// 4) After server boots: source + demo     //
//////////////////////////////////////////////
~afterBoot = {
    // Per-proxy fade times (no global setter on Ndef)
    Ndef(\src).source = {
        var chs, sig;
        chs = Array.series(~numCh ? 6, 0, 1);   // [0,1,2,3,4,5]
        sig = SoundIn.ar(chs);
        sig
    };
    Ndef(\src).fadeTime = ~jitFadeTime ? 0.25;

    // Log devices actually in use
    ("Input device:  "  ++ s.options.inDevice).postln;
    ("Output device: " ++ s.options.outDevice).postln;

    // An audibly obvious, safe demo chain (HEAD = \guitar)
    ~demoSpec = [
        \guitar,
        [\chopTrem, (id: \ch1, rate: 6, depth: 0.8)],
        [\ringmod,  (id: \rm1, freq: 180, mix: 0.5)],
        [\slapback, (id: \sb1, time: 0.12, mix: 0.35)],
        \destination
    ];

    // Build with crossfade if available; else legacy build
    (~jitBuildCF.notNil).if({
        ~jitBuildCF.(~demoSpec)
    },{
        ~jitBuild.(~demoSpec)
    });

    // Start audio if your v2 exposes ~jitPlay
    (~jitPlay.notNil).if({ ~jitPlay.() });

    // Show GUI (uses listeners if you’ve wired ~jitNotify; else timer mode is OK too)
    (~jitGuiShow.notNil).if({ ~jitGuiShow.(useListeners: true) });
};

/////////////////////////
// 5) Run the session  //
/////////////////////////
~loadAll.();

// If server already running, options won't apply until reboot; still run afterBoot
(s.serverRunning).if({
    "[info] Server already running; using current devices.".postln;
    ~afterBoot.();
}, {
    s.waitForBoot({ ~afterBoot.() });
    s.boot;
});
)
