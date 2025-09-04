// jit_config_v6.scd
// Session-wide defaults, toggles, and registry initialization for jit signal chain system.
// Ensures robust, idempotent, and clear initialization of session state.

(
    // --- Idempotency guard: only run once per session ---
    ~jitConfigLoaded = (~jitConfigLoaded ? false);

    ~jitConfigLoaded.if({
        // Already loaded. Skip reapplying values.
        ("[jit][CFG v6] already loaded; skipping — " ++ thisProcess.nowExecutingPath).postln;
    },{
        ~jitConfigLoaded = true;
        ("[jit][CFG v6 self-contained] loaded from: " ++ thisProcess.nowExecutingPath).postln;

        // --- Core session parameters ---
        // Number of input channels (hexaphonic guitar: usually 6)
        ~numCh         = (~numCh.isNil or: { ~numCh == 0 })   ?? 6;
        ~numCh         = ~numCh.asInteger.clip(1, 64);

        // Output bus offset (usually 0)
        ~outOffset     = (~outOffset.isNil) ?? 0;
        ~outOffset     = ~outOffset.asInteger.max(0);

        // Input and output amp levels (floats 0..2)
        ~sourceAmp     = (~sourceAmp.isNil) ?? 0.6;
        ~sourceAmp     = ~sourceAmp.asFloat.clip(0, 2);

        ~defaultAmp    = (~defaultAmp.isNil) ?? 0.8;
        ~defaultAmp    = ~defaultAmp.asFloat.clip(0, 2);

        // Default fade time for transitions (seconds)
        ~jitFadeTime   = (~jitFadeTime.isNil) ?? 0.25;
        ~jitFadeTime   = ~jitFadeTime.asFloat.max(0.0);

        // --- Session toggles ---
        // Use true/false for booleans only
        ~jitUseRealInput     = (~jitUseRealInput.isNil) ?? false;
        ~jitUseSplayDownmix  = (~jitUseSplayDownmix.isNil) ?? false;

	// --- Display / Version label (used by GUI and status) ---
        // Keep a single source of truth for UI strings
        ~displayVersion = (~displayVersion.isNil) ?? "v6";

        // --- Source selection (BlackHole vs Test) ---
        // New explicit mode that chooses where the source comes from:
        //   \blackhole  -> device input via SoundIn
        //   \test       -> internal 6ch hex test generator
        //
        // Backward compatibility:
        // If ~sourceMode is not already set, derive it from ~jitUseRealInput.
        // (true -> \blackhole, false -> \test)
        ~sourceMode = (~sourceMode.isNil) ?? (
            (~jitUseRealInput == true).if(\blackhole, \test)
        );


        // --- NodeProxy fade time ---
        if(NodeProxy.respondsTo(\defaultFadeTime_)) {
            NodeProxy.defaultFadeTime = ~jitFadeTime;
        };

        // --- Runtime registries ---
        // Used for tracking chain stages and session state
        ~jitStageIndexNodes = (~jitStageIndexNodes.isNil) ?? [];
        ~jitStageIdInfo     = (~jitStageIdInfo.isNil) ?? IdentityDictionary.new;
        ~jitCurrentSpec     = (~jitCurrentSpec.isNil) ?? nil;

        // --- Quick clear for registries: resets session state without affecting server ---
        ~jitClearState = {
            ~jitStageIndexNodes = [];
            ~jitStageIdInfo.clear;
            ~jitCurrentSpec = nil;
        };

        // --- Reserved for future parameters ---
        // ~jitExtraParams = IdentityDictionary.new; // For future expansion
    });
)