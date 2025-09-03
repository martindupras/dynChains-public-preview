// jit_chain_utils_v3.scd
// MD 20250829

(
/* ====================================================
   Utilities for working with the chain:
   - Spec slicing & assembly
   - Array-safe edit-ops (insert / remove / move)
   - Setters for source/destination/stage parameters
   - Stage info lookup (index or id)
   - Introspection helpers
   Load after: jit_chain_core_v3.scd
   ===================================================== */

// ---- Array helper (Array-safe removeAt via slicing) ----
~jitArrayRemoveAt = { |arr, index|
    var n, idx;
    n = arr.size;
    (n <= 0).if({
        []
    },{
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

// --- helpers for GUI
~jitListeners = ~jitListeners ? Array.new;
~jitAddListener = { |fn| (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) }) };
~jitRemoveListener = { |fn| ~jitListeners = ~jitListeners.reject(_ == fn) };

// (Removed eager broadcast at load; unified via ~jitNotify below)


// ---- Spec utilities (extract/replace stages between \guitar and destination) ----
~jitSpecStages = { |spec|
    var stages;
    stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
    stages
};

~jitSpecWithStages = { |spec, newStages|
    var head, tail;
    head = spec.first;  // \guitar
    tail = spec.last;   // \destination or \destinationStereo
    [head] ++ newStages ++ [tail]
};

// ---- Edit operations (Array-safe: use insert + slice-based remove) ----
~jitInsertStage = { |position, stageEntry|
    var spec, stages, pos, symArgs, sym, builder, newStages, newSpec;

    spec = (~jitCurrentSpec ? nil);
    (spec.isNil).if({
        "[WARN] ~jitInsertStage: no current spec.".warn; nil
    },{
        symArgs = ~jitNormalizeStage.(stageEntry);
        sym = symArgs[0];
        builder = (~fxBuilders ? nil);
        ((builder.isNil) or: { ~fxBuilders[sym].isNil }).if({
            ("[WARN] ~jitInsertStage: unknown stage symbol " ++ sym.asString).warn; nil
        },{
            stages = ~jitSpecStages.(spec);
            pos = position.clip(0, stages.size);
            newStages = stages.insert(pos, stageEntry);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            ~jitBuild.(newSpec)
        })
    })
};

~jitRemoveStage = { |which|
    var spec, stages, idx, newStages, newSpec;

    spec = (~jitCurrentSpec ? nil);
    (spec.isNil).if({
        "[WARN] ~jitRemoveStage: no current spec.".warn; nil
    },{
        stages = ~jitSpecStages.(spec);

        idx = which.isNumber.if({
            which.asInteger.clip(0, stages.size - 1)
        },{
            var targetId;
            targetId = which;
            stages.detectIndex { |entry|
                var symArgs, idAndDict, id;
                symArgs = ~jitNormalizeStage.(entry);
                idAndDict = ~jitExtractIdAndDict.(symArgs[1]);  // -> [id, dict]
                id = idAndDict[0];
                id == targetId
            }
        });

        (idx.isNil).if({
            ("[WARN] ~jitRemoveStage: stage not found: " ++ which.asString).warn; nil
        },{
            newStages = ~jitArrayRemoveAt.(stages, idx);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            ~jitBuild.(newSpec)
        })
    })
};

~jitMoveStage = { |which, newPosition|
    var spec, stages, idx, entry, tmpStages, newIdx, newStages, newSpec;

    spec = (~jitCurrentSpec ? nil);
    (spec.isNil).if({
        "[WARN] ~jitMoveStage: no current spec.".warn; nil
    },{
        stages = ~jitSpecStages.(spec);

        idx = which.isNumber.if({
            which.asInteger.clip(0, stages.size - 1)
        },{
            var targetId;
            targetId = which;
            stages.detectIndex { |entry0|
                var symArgs, idAndDict, id;
                symArgs = ~jitNormalizeStage.(entry0);
                idAndDict = ~jitExtractIdAndDict.(symArgs[1]);  // -> [id, dict]
                id = idAndDict[0];
                id == targetId
            }
        });

        (idx.isNil).if({
            ("[WARN] ~jitMoveStage: stage not found: " ++ which.asString).warn; nil
        },{
            entry = stages[idx];
            tmpStages = ~jitArrayRemoveAt.(stages, idx);
            newIdx = newPosition.clip(0, tmpStages.size);
            newStages = tmpStages.insert(newIdx, entry);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            ~jitBuild.(newSpec)
        })
    })
};

// ---- Stage info and param flattening ----
~jitStagePrefixFor = (~jitStagePrefixFor ? ~jitStagePrefixFor);  // defined in core
~jitGetStageInfo = { |which|
    which.isNumber.if({
        var slot;
        slot = which.asInteger;
        if((slot < 0) or: { slot >= ~jitStageIndexNodes.size }) {
            nil
        }{
            (slot: slot, prefix: (~jitStageIndexNodes[slot] ?? { ("fx" ++ slot) }).asString)
        }
    },{
        ~jitStageIdInfo[which]
    })
};

~toKeyValueArray = { |params|
    var kv;
    (params.isNil).if({
        nil
    },{
        params.respondsTo(\keysValuesDo).if({
            kv = List.new;
            params.keysValuesDo { |k, v| kv.addAll([k, v]) };
            kv.asArray
        },{
            params.isSequenceableCollection.if({
                params.asArray
            },{
                nil
            })
        })
    })
};

// ---- Setters ----
~jitSetFx = { |which, params|
    var info, prefix, kvPairs, rewritten;

    info = ~jitGetStageInfo.(which);
    (info.isNil).if({
        ("No such stage: " ++ which.asString).warn; nil
    },{
        prefix  = info[\prefix].asString;
        kvPairs = ~toKeyValueArray.(params);

        (kvPairs.isNil).if({
            ("~jitSetFx: params not understood for " ++ which.asString
                ++ " → " ++ params.asString).warn; nil
        },{
            rewritten = Array.new;
            kvPairs.clump(2).do { |kv|
                rewritten.addAll([
                    (prefix ++ "_" ++ kv[0].asString).asSymbol, kv[1]
                ]);
            };
            Ndef(\chain).set(*rewritten);
            info
        })
    })
};

~jitSetSource = { |params|
    var kvPairs;
    kvPairs = ~toKeyValueArray.(params);
    (kvPairs.isNil).if({
        "[WARN] ~jitSetSource: params not understood.".warn; nil
    },{
        Ndef(\chain).set(*kvPairs)
    })
};

~jitSetDest = { |params|
    var kvPairs;
    kvPairs = ~toKeyValueArray.(params);
    (kvPairs.isNil).if({
        "[WARN] ~jitSetDest: params not understood.".warn; nil
    },{
        Ndef(\out).set(*kvPairs)
    })
};

// ---- Introspection ----
~jitStatus = {
    var specStr, idMapStr, nodesStr;
    specStr = (~jitCurrentSpec ? "nil").asString;
    idMapStr = (~jitStageIdInfo ? IdentityDictionary.new).asString;
    nodesStr = (~jitStageIndexNodes ? []).asString;
    ("--- JIT Status ---").postln;
    ("Spec: " ++ specStr).postln;
    ("Stage Index Nodes: " ++ nodesStr).postln;
    ("ID Map: " ++ idMapStr).postln;
    ("Ndef(\\chain) channels: " ++ Ndef(\chain).numChannels).postln;
    ("Ndef(\\out)   channels: " ++ Ndef(\out).numChannels).postln;
    ("fadeTime: " ++ ~jitFadeTime.asString
        ++ " | numCh: " ++ ~numCh.asString
        ++ " | outOffset: " ++ ~outOffset.asString
        ++ " | useRealInput: " ++ ((~jitUseRealInput ? false) == true).asString
        ++ " | splayDownmix: " ++ (~jitUseSplayDownmix ? false).asString).postln;
    ("-------------------").postln;
};

~jitDebugDump = {
    ("[jit] index nodes: " ++ (~jitStageIndexNodes ? []).asString).postln;
    ("[jit] id info: " ++ (~jitStageIdInfo ? IdentityDictionary.new).asString).postln;
};


// --------------------------------------------------------------------
// --- merged from jit_chain_utils_v2_patch.scd (v3 integration) -----
// - HTML entities fixed (already normalized above)
// - Listener API formalized
// - Removed eager broadcast at load
// --------------------------------------------------------------------

// Listener registry (no eager broadcast on load)
~jitListeners = ~jitListeners ? Array.new;
~jitAddListener = { |fn| (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) }) };
~jitRemoveListener = { |fn| ~jitListeners = ~jitListeners.reject(_ == fn) };

// Central notifier; GUI callers typically defer; we also .defer here for safety
~jitNotify = { |phase, payload = nil|
    var arr;
    arr = (~jitListeners ? Array.new);
    arr.do { |fn| { fn.value(phase, payload) }.defer };
};

// Convenience wrappers
~jitNotifyWillBuild  = { |spec| ~jitNotify.(\willBuild, (spec: spec)) };
~jitNotifyDidBuild   = { |spec| ~jitNotify.(\didBuild,  (cur: spec, next: ~jitNextSpec)) };
~jitNotifyWillSwitch = { |from, to, fade, tail|
    var f, t;
    f = fade ? (~jitFadeTime ? 0.25);
    t = tail ? 0.0;
    ~jitNotify.(\willSwitch, (from: from, to: to, fade: f, tail: t))
};
~jitNotifyDidSwitch  = { |active, spec| ~jitNotify.(\didSwitch, (active: active, spec: spec)) };

// Array helper (kept with real comparison operators)
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

// Spec utilities with real comparisons
~jitSpecStages = { |spec|
    var stages;
    stages = (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] });
    stages
};

// Stage info bounds check with real ops + nil-guard on ~jitStageIndexNodes
~jitGetStageInfo = { |which|
    which.isNumber.if({
        var slot, arr;
        slot = which.asInteger;
        arr = (~jitStageIndexNodes ? []);
        if((slot < 0) or: { slot >= arr.size }) {
            nil
        }{
            (slot: slot, prefix: ((arr[slot] ?? { ("fx" ++ slot) })).asString)
        }
    },{
        ~jitStageIdInfo[which]
    })
};

// --- v3 chain UX helpers: preview + build + switch (additive; no behavior changes) ---
// --- Keep CF mixer active after builds; adopt current into active slot if possible ---
~jitCFEnsureMixer = {
    var ft, tl;
    if(~jitCFEnabled == true) {
        ft = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
        tl = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 });
        ~jitSetCrossfade.(ft, tl);  // re-install XFade2 on Ndef(\out) after ~jitBuild overwrote it
    };
};

// Build a spec and always notify GUI/listeners; if CF enabled, adopt & re-install mixer
~jitBuildAndNotify = { |spec|
    var s, act;
    s = spec;

    ~jitNotifyWillBuild.(s);
    ~jitBuild.(s);

    // If CF is enabled, ensure the mixer is Ndef(\out) again, and feed the active side
    if(~jitCFEnabled == true) {
        // adopt current into the active slot (if per-slot builder exists)
        if(~jitBuildIntoChain.isFunction) {
            act = (~jitActiveChain ? \A);
            ~jitBuildCF.(act, s);
        };
        ~jitCFEnsureMixer.();
    };

    ~jitNotifyDidBuild.(s);
};

/*// Build a spec and always notify GUI/listeners.
~jitBuildAndNotify = { |spec|
    var s;
    s = spec;
    ~jitNotifyWillBuild.(s);
    ~jitBuild.(s);
    ~jitNotifyDidBuild.(s);
};*/

// Set the "next" spec for display (second row) and refresh GUI.
~jitSetNextSpec = { |spec|
    var s;
    s = spec;
    ~jitNextSpec = s;
    ~jitGuiState = (~jitGuiState ? ());  // ensure it exists
    ~jitGuiState[\showNext] = true;
    ~jitNotify.(\preview, (next: s, cur: ~jitCurrentSpec));
    (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
};

// Switch to the "next" spec immediately (no scheduling).
// Still emits will/did switch notifications so the GUI reflects the change.
~jitSwitchToNextNow = {
    var cur, nxt, fade, tail, act;
    cur  = ~jitCurrentSpec;
    nxt  = ~jitNextSpec ? cur;

    // Keep fade/tail resilient even if CF didn’t load.
    fade = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({
        ~jitCF[\fadeTime]
    },{
        (~jitFadeTime ? 0.25)
    });
    tail = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({
        ~jitCF[\tailHold]
    },{
        0.0
    });

    // Best-effort active chain reporting (does not change CF behavior).
    act = (~jitActiveChain ? \A);

    ~jitNotifyWillSwitch.(cur, nxt, fade, tail);

    ~jitBuildAndNotify.(nxt);
    ~jitNextSpec = nil;

    ~jitNotifyDidSwitch.(act, nxt);

    (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
};

// Schedule a switch to the currently queued "next" spec after N seconds (AppClock).
~jitScheduleSwitchToNext = { |seconds = 0|
    var d;
    d = seconds.max(0);
    AppClock.sched(d, {
        ~jitSwitchToNextNow.();
        nil
    });
};

// Convenience: preview a spec *and* schedule the switch.
~jitPreviewAndSchedule = { |spec, seconds = 0|
    var s, d;
    s = spec; d = seconds;
    ~jitSetNextSpec.(s);
    ~jitScheduleSwitchToNext.(d);
};
// --------------------------------------------------------------------
// CF-aware helpers (additive; non-breaking)
// - Works with or without crossfade module loaded
// - Emits notifications so the GUI reflects preview/build/switch
// - No server.sync, no try/protect; tilde-globals only
// --------------------------------------------------------------------

/* Adapter dictionary: your crossfade module can populate these slots.
   If they are absent, helpers fall back to non-CF behavior (instant build). */
~jitCFAdapter = ~jitCFAdapter ? (
    /* Build the INACTIVE chain slot with 'spec' (does NOT switch). */
    buildInactive: nil,      // expects a Function |spec|

    /* Perform the actual crossfade/switch NOW. */
    switchNow: nil,          // expects a Function |fade, tail|

    /* Schedule a switch in 'seconds' on AppClock (or TempoClock), if your CF wants to. */
    switchIn: nil,           // expects a Function |seconds, fade, tail|

    /* Report active slot/symbol (e.g. \A or \B). */
    activeSlot: { ~jitActiveChain ? \A }
);

/* Resolve fade/tail with robust nil-guards (even if CF didn't load). */
~jitCF_resolveFadeTail = {
    var fade, tail;
    fade = if(~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }, { ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
    tail = if(~jitCF.notNil and: { ~jitCF[\tailHold].notNil }, { ~jitCF[\tailHold] }, { 0.0 });
    (fade: fade, tail: tail)
};

/* Preview "next" spec: build inactive slot if CF adapter present; always update GUI */
~jitCFPreview = { |spec|
    var s, hasBuildInactive;
    s = spec;
    hasBuildInactive = (~jitCFEnabled == true)
        and: { ~jitCFAdapter.notNil }
        and: { ~jitCFAdapter[\buildInactive].isFunction };

    // Notify & GUI next-row
    ~jitSetNextSpec.(s);

    hasBuildInactive.if({
        ~jitNotify.(\willBuildInactive, (spec: s));
        ~jitCFAdapter[\buildInactive].(s);
        ~jitNotify.(\didBuildInactive, (spec: s));
    },{
        // No CF builder -> do nothing more; next row still previews
        nil
    });
};

/* Switch NOW to the queued "next" spec, using CF if available; otherwise fallback to instant rebuild */
/*~jitCFSwitchNow = { |fade = nil, tail = nil|
    var cur, nxt, ft, tl, act, canCF;

    cur = ~jitCurrentSpec;
    nxt = ~jitNextSpec ? cur;

    # ft, tl = [
        (fade ?? { ~jitCF_resolveFadeTail.()[\fade] }),
        (tail ?? { ~jitCF_resolveFadeTail.()[\tail] })
    ];

    act = (~jitCFAdapter[\activeSlot].isFunction).if({ ~jitCFAdapter[\activeSlot].() }, { ~jitActiveChain ? \A });

    ~jitNotifyWillSwitch.(cur, nxt, ft, tl);

    canCF = (~jitCFEnabled == true)
        and: { ~jitCFAdapter.notNil }
        and: { ~jitCFAdapter[\switchNow].isFunction };

    canCF.if({
        // Crossfade via adapter (audio switch handled by CF)
        ~jitCFAdapter[\switchNow].(ft, tl);

        // Keep book-keeping in UI: current spec becomes next; clear next
        ~jitBuildAndNotify.(nxt);
        ~jitNextSpec = nil;

        ~jitNotifyDidSwitch.(act, nxt);
        (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });

    },{
        // Fallback: instant rebuild (no crossfade)
        ~jitSwitchToNextNow.();
    });
};*/

/* Schedule switch in 'seconds' (AppClock), using CF if available */
~jitCFSwitchIn = { |seconds = 0.0, fade = nil, tail = nil|
    var d, ft, tl, canCF;
    d = seconds.max(0);

    # ft, tl = [
        (fade ?? { ~jitCF_resolveFadeTail.()[\fade] }),
        (tail ?? { ~jitCF_resolveFadeTail.()[\tail] })
    ];

    canCF = (~jitCFEnabled == true)
        and: { ~jitCFAdapter.notNil }
        and: { ~jitCFAdapter[\switchIn].isFunction };

    canCF.if({
        // Let CF module schedule precisely as it prefers
        ~jitCFAdapter[\switchIn].(d, ft, tl);
    },{
        // Generic AppClock schedule (then go via switchNow)
        AppClock.sched(d, { ~jitCFSwitchNow.(ft, tl); nil });
    });
};

/* Convenience: preview "spec" into inactive, then schedule a switch */
~jitCFPreviewAndSwitchIn = { |spec, seconds = 0.0, fade = nil, tail = nil|
    var s, d, ft, tl;
    s = spec; d = seconds.max(0);

    # ft, tl = [
        (fade ?? { ~jitCF_resolveFadeTail.()[\fade] }),
        (tail ?? { ~jitCF_resolveFadeTail.()[\tail] })
    ];

    ~jitCFPreview.(s);
    ~jitCFSwitchIn.(d, ft, tl);
};


// -----------------------------------------------
// Minimal guards + CF mixer keep-alive
// -----------------------------------------------
/*
// Predicate: is this a reasonably-formed spec?
~jitIsValidSpec = ~jitIsValidSpec ? { |spec|
    var ok, last;
    ok = spec.notNil and: { spec.isArray } and: { spec.size >= 2 } and: { spec.first == \guitar };
    ok = ok and: {
        last = spec.last;
        (last == \destination) or: { last == \destinationStereo }
    };
    ok
};*/

// Keep the crossfade mixer active on Ndef(\out) after builds
/*~jitCFEnsureMixer = ~jitCFEnsureMixer ? {
    var ft, tl;
    if(~jitCFEnabled == true) {
        ft = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
        tl = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 });
        ~jitSetCrossfade.(ft, tl);
    };
};*/

// Build a spec and always notify GUI/listeners; CF-safe
/*~jitBuildAndNotify = { |spec|
    var s, act;
    s = spec;

    (~jitIsValidSpec.(s)).if({
        ~jitNotifyWillBuild.(s);
        ~jitBuild.(s);

        if(~jitCFEnabled == true) {
            if(~jitBuildIntoChain.isFunction) {
                act = (~jitActiveChain ? \A);
                ~jitBuildCF.(act, s);     // feed the active side
            };
            ~jitCFEnsureMixer.();
        };

        ~jitNotifyDidBuild.(s);
    },{
        ("[jit] ~jitBuildAndNotify: invalid spec — " ++ s.asString).warn;
        nil
    });
};*/

// Preview a next spec; build inactive if CF adapter is present (defer build to next tick)
/*~jitCFPreview = { |spec|
    var s, hasBuildInactive;
    s = spec;

    (~jitIsValidSpec.(s)).if({
        ~jitSetNextSpec.(s);  // show second row
        hasBuildInactive = (~jitCFEnabled == true)
            and: { ~jitCFAdapter.notNil }
            and: { ~jitCFAdapter[\buildInactive].isFunction };

        hasBuildInactive.if({
            ~jitNotify.(\willBuildInactive, (spec: s));
            { ~jitCFAdapter[\buildInactive].(s); ~jitNotify.(\didBuildInactive, (spec: s)) }.defer; // <-- defer one UI tick
        });
    },{
        ("[jit] ~jitCFPreview: invalid spec — " ++ s.asString).warn;
        nil
    });
};*/

// // Preview a next spec; build inactive if CF adapter is present
// ~jitCFPreview = { |spec|
// 	var s, hasBuildInactive;
// 	s = spec;
//
// 	(~jitIsValidSpec.(s)).if({
// 		~jitSetNextSpec.(s);  // show second row
// 		hasBuildInactive = (~jitCFEnabled == true)
// 		and: { ~jitCFAdapter.notNil }
// 		and: { ~jitCFAdapter[\buildInactive].isFunction };
// 		hasBuildInactive.if({
// 			~jitNotify.(\willBuildInactive, (spec: s));
// 			~jitCFAdapter[\buildInactive].(s);
// 			~jitNotify.(\didBuildInactive, (spec: s));
// 		});
// 		},{
// 			("[jit] ~jitCFPreview: invalid spec — " ++ s.asString).warn;
// 			nil
// 	});
// };

// Immediate CF switch with deterministic 'next' clearing + GUI refresh
~jitCFSwitchNow = { |fade = nil, tail = nil|
    var cur, nxt, ft, tl, act, canCF;

    cur = ~jitCurrentSpec;
    nxt = ~jitNextSpec ? cur;

    // Guard: need a valid next spec
    (~jitIsValidSpec.(nxt)).if({
        // Resolve times with robust nil-guards
        # ft, tl = [
            (fade ?? { (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { ~jitFadeTime ? 0.25 }) }),
            (tail ?? { (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 }) })
        ];

        // Early-clear 'next' so GUI logic is deterministic
        ~jitNextSpec = nil;

        // Active slot readout (if adapter exposes it)
        act = (~jitCFAdapter.notNil and: { ~jitCFAdapter[\activeSlot].isFunction }).if({
            ~jitCFAdapter[\activeSlot].()
        },{
            ~jitActiveChain ? \A
        });

        ~jitNotifyWillSwitch.(cur, nxt, ft, tl);

        // CF path or fallback
        canCF = (~jitCFEnabled == true)
            and: { ~jitCFAdapter.notNil }
            and: { ~jitCFAdapter[\switchNow].isFunction };

        canCF.if({
            // Audio crossfade now (adapter only handles DSP)
            ~jitCFAdapter[\switchNow].(ft, tl);

            // Update language-side 'current', notify, and ensure mixer
            ~jitBuildAndNotify.(nxt);
            ~jitNotifyDidSwitch.(act, nxt);
            (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
        },{
            // Fallback: instant rebuild
            ~jitSwitchToNextNow.();
        });
    },{
        "[jit] ~jitCFSwitchNow: no next spec to switch to.".warn
    });
};

// // Optional: guard immediate switch helper too (in case ~jitNextSpec is missing)
// ~jitCFSwitchNow = ~jitCFSwitchNow ? { |fade = nil, tail = nil|
// 	var cur, nxt, ft, tl, act, canCF;
//
// 	cur = ~jitCurrentSpec;
// 	nxt = ~jitNextSpec ? cur;
//
// 	(~jitIsValidSpec.(nxt)).if({
// 		# ft, tl = [
// 			(fade ?? { (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { ~jitFadeTime ? 0.25 }) }),
// 			(tail ?? { (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 }) })
// 		];
//
// 		act = (~jitCFAdapter.notNil and: { ~jitCFAdapter[\activeSlot].isFunction }).if({
// 			~jitCFAdapter[\activeSlot].()
// 			},{
// 				~jitActiveChain ? \A
// 		});
//
// 		~jitNotifyWillSwitch.(cur, nxt, ft, tl);
//
// 		canCF = (~jitCFEnabled == true)
// 		and: { ~jitCFAdapter.notNil }
// 		and: { ~jitCFAdapter[\switchNow].isFunction };
//
// 		canCF.if({
// 			~jitCFAdapter[\switchNow].(ft, tl);
// 			~jitBuildAndNotify.(nxt);  // book-keeping + GUI
// 			~jitNextSpec = nil;
// 			~jitNotifyDidSwitch.(act, nxt);
// 			(~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
// 			},{
// 				// fallback path if CF is not wired
// 				~jitSwitchToNextNow.();
// 		});
// 		},{
// 			"[jit] ~jitCFSwitchNow: no next spec to switch to.".warn
// 	});
// };


// -----------------------------------------------
// Guards + CF mixer keep-alive + gentle defers
// -----------------------------------------------

~jitIsValidSpec = ~jitIsValidSpec ? { |spec|
    var ok, last;
    ok = spec.notNil and: { spec.isArray } and: { spec.size >= 2 } and: { spec.first == \guitar };
    ok = ok and: {
        last = spec.last;
        (last == \destination) or: { last == \destinationStereo }
    };
    ok
};

~jitCFEnsureMixer = ~jitCFEnsureMixer ? {
    var ft, tl;
    if(~jitCFEnabled == true) {
        ft = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
        tl = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 });
        ~jitSetCrossfade.(ft, tl);  // puts XFade2 back on Ndef(\out) after ~jitBuild
    };
};

// Build a spec and always notify; if CF enabled, adopt into active side (defer) and re-install mixer
~jitBuildAndNotify = { |spec|
    var s, act;
    s = spec;

    (~jitIsValidSpec.(s)).if({
        ~jitNotifyWillBuild.(s);
        ~jitBuild.(s);

        if(~jitCFEnabled == true) {
            if(~jitBuildIntoChain.isFunction) {
                act = (~jitActiveChain ? \A);
                { ~jitBuildCF.(act, s) }.defer;  // gentle defer to avoid /d_recv races
            };
            ~jitCFEnsureMixer.();
        };

        ~jitNotifyDidBuild.(s);
    },{
        ("[jit] ~jitBuildAndNotify: invalid spec — " ++ s.asString).warn;
        nil
    });
};

// Preview a next spec; build inactive if CF adapter is present (defer inactive build)
~jitCFPreview = { |spec|
    var s, hasBuildInactive;
    s = spec;

    (~jitIsValidSpec.(s)).if({
        ~jitSetNextSpec.(s);  // second row

        hasBuildInactive = (~jitCFEnabled == true)
            and: { ~jitCFAdapter.notNil }
            and: { ~jitCFAdapter[\buildInactive].isFunction };

        hasBuildInactive.if({
            ~jitNotify.(\willBuildInactive, (spec: s));
            { ~jitCFAdapter[\buildInactive].(s); ~jitNotify.(\didBuildInactive, (spec: s)) }.defer;
        });
    },{
        ("[jit] ~jitCFPreview: invalid spec — " ++ s.asString).warn;
        nil
    });
};

// Immediate CF switch with early-clearing of ~jitNextSpec and deterministic GUI update
~jitCFSwitchNow = { |fade = nil, tail = nil|
    var cur, nxt, ft, tl, act, canCF;

    cur = ~jitCurrentSpec;
    nxt = ~jitNextSpec ? cur;

    (~jitIsValidSpec.(nxt)).if({
        // Resolve times
        # ft, tl = [
            (fade ?? { (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { ~jitFadeTime ? 0.25 }) }),
            (tail ?? { (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 }) })
        ];

        // Early clear: GUI tests will see 'next' cleared immediately
        ~jitNextSpec = nil;

        // Active side readout (if adapter provides it)
        act = (~jitCFAdapter.notNil and: { ~jitCFAdapter[\activeSlot].isFunction }).if({
            ~jitCFAdapter[\activeSlot].()
        },{
            ~jitActiveChain ? \A
        });

        ~jitNotifyWillSwitch.(cur, nxt, ft, tl);

        // CF path or fallback
        canCF = (~jitCFEnabled == true)
            and: { ~jitCFAdapter.notNil }
            and: { ~jitCFAdapter[\switchNow].isFunction };

        canCF.if({
            ~jitCFAdapter[\switchNow].(ft, tl);     // DSP crossfade now
            ~jitBuildAndNotify.(nxt);               // book-keeping + (deferred) adopt + mixer
            ~jitNotifyDidSwitch.(act, nxt);
            (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
        },{
            ~jitSwitchToNextNow.();                 // non-CF fallback
        });
    },{
        "[jit] ~jitCFSwitchNow: no next spec to switch to.".warn
    });
};

/* --- CF small helpers (v3) --- */

/* Return the inactive side based on ~jitCFActiveSide. Defaults to \A active on first run. */
~jitCFGetInactiveSide = {
    var active;
    active = ~jitCFActiveSide ? \A;
    if(active == \A) { \B } { \A }
};

/* Deterministic, immediate switch:
   - Early-clear ~jitNextSpec,
   - Update ~jitCurrentSpec,
   - Start DSP crossfade (delegates to engine),
   - Single GUI refresh on next AppClock tick,
   - didSwitch notification on the same tick. */
~jitCFSwitchNow = {
    var newSpec, refreshFunc, fade, tail;
    var targetSide;

    fade = ~jitCFFade ? 0.05;
    tail = ~jitCFTail ? 0.20;

    // Which DSP side are we switching to? (inactive one — preview was built there)
    targetSide = ~jitCFGetInactiveSide.();

    // Bookkeeping first (early clear so GUI can drop "Next" deterministically)
    newSpec = ~jitNextSpec ? ~jitCurrentSpec;
    ~jitCurrentSpec = newSpec;
    ~jitNextSpec = nil;

    // Optional notification before DSP (guarded)
    if(~jitNotifyWillSwitch.notNil) { ~jitNotifyWillSwitch.(newSpec) };

    // DSP: begin the crossfade to the inactive side
    ~jitStartCrossfadeTo.(targetSide, fade, tail);

    // One GUI refresh and didSwitch post on the next AppClock tick to beat any deferred preview/build races
    refreshFunc = {
        if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
        if(~jitNotifyDidSwitch.notNil) { ~jitNotifyDidSwitch.(newSpec) } { "[jitCF] didSwitch".postln };
        0
    };
    AppClock.sched(0, refreshFunc);
};

/* Scheduled switch helper: schedules ~jitCFSwitchNow (so GUI/bookkeeping is correct). */
~jitCFSwitchIn = { |sec = 0.5|
    var t;
    t = sec.max(0.0);
    AppClock.sched(t, {
        ~jitCFSwitchNow.();
        0
    });
};

/* Language-side health probe (for testing only). */

/* Language-side liveness check for CF:
   - posts numChannels for outA/outB,
   - posts last known gates (tracked in engine under \outA/\outB),
   - confirms mixer Ndef(\out) has a source. */
~jitCFAssertLive = {
    var outA, outB, mix, chansA, chansB, gates, gateA, gateB, hasMixer;
    outA = Ndef(\outA);
    outB = Ndef(\outB);
    mix  = Ndef(\out);

    chansA = outA.numChannels ? -1;
    chansB = outB.numChannels ? -1;

    gates = ~jitCFGates ? IdentityDictionary.new;
    gateA = gates[\outA] ? 'unknown';
    gateB = gates[\outB] ? 'unknown';

    hasMixer = mix.source.notNil;

    ("[CF Assert] outA chans=% gate=%  |  outB chans=% gate=%".format(chansA, gateA, chansB, gateB)).postln;
    ("[CF Assert] mixer present? " ++ hasMixer).postln;
};

/*~jitCFAssertLive = {
    var outA, outB, mix, chansA, chansB, gatesA, gatesB, xfadeInstalled;
    outA = Ndef(\outA);
    outB = Ndef(\outB);
    mix  = Ndef(\out);

    chansA = outA.numChannels ? -1;
    chansB = outB.numChannels ? -1;

    // We cache the last gate values we set in the engine (avoids async .get)
    ~jitCFGates = ~jitCFGates ? IdentityDictionary.new;
    gatesA = ~jitCFGates[\outA] ? 'unknown';
    gatesB = ~jitCFGates[\outB] ? 'unknown';

    xfadeInstalled = ~jitXFadeInstalled ? false;

    ("[CF Assert] outA chans=%  outB chans=%".format(chansA, chansB)).postln;
    ("[CF Assert] gates: outA=%  outB=%".format(gatesA, gatesB)).postln;
    ("[CF Assert] mixer.hasObjects? " ++ (mix.objects.notNil)).postln;
    ("[CF Assert] XFade installed? " ++ xfadeInstalled).postln;
};*/

/* --- CF helpers (v3 minimal, patched returns) --- */

~jitCFGetInactiveSide = {
    var active;
    active = ~jitCFActiveSide ? \A;
    if(active == \A) { \B } { \A }
};

~jitCFSwitchNow = {
    var newSpec, targetSide, fade, tail;

    fade = ~jitCFFade ? (~jitCFFadeTime ? 0.05);
    tail = ~jitCFTail ? (~jitCFTailTime ? 0.20);

    newSpec = ~jitNextSpec ? ~jitCurrentSpec;
    ~jitCurrentSpec = newSpec;
    ~jitNextSpec = nil;

    if(~jitNotifyWillSwitch.notNil) { ~jitNotifyWillSwitch.(newSpec) };

    targetSide = ~jitCFGetInactiveSide.();
    ~jitStartCrossfadeTo.(targetSide, fade, tail);

    AppClock.sched(0, {
        if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() };
        if(~jitNotifyDidSwitch.notNil) { ~jitNotifyDidSwitch.(newSpec) };
        nil  // <-- run once
    });
};

~jitCFSwitchIn = { |sec = 0.5|
    var t;
    t = sec.max(0.0);
    AppClock.sched(t, {
        ~jitCFSwitchNow.();
        nil  // <-- run once
    });
};

/* CF liveness probe */
~jitCFAssertLive = {
    var outA, outB, mix, chansA, chansB, gates, gateA, gateB, hasMixer;
    outA = Ndef(\outA);
    outB = Ndef(\outB);
    mix  = Ndef(\out);

    chansA = outA.numChannels ? -1;
    chansB = outB.numChannels ? -1;

    gates = ~jitCFGates ? IdentityDictionary.new;
    gateA = gates[\outA] ? 'unknown';
    gateB = gates[\outB] ? 'unknown';

    hasMixer = mix.source.notNil;

    ("[CF Assert] outA chans=% gate=%  |  outB chans=% gate=%".format(chansA, gateA, chansB, gateB)).postln;
    ("[CF Assert] mixer present? " ++ hasMixer).postln;
};



)
