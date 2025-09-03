// jit_chain_utils_v4.scd
// MD 20250903 — v4 utils (tilde-globals only; var-first; caret-free; no server.sync; no try/protect)
// Notes:
//  • Removes CF helpers duplicated in v3 (v4 CF engine provides ~jitCFPreview/~jitCFSwitchNow/~jitCFSwitchIn).
//  • Adds silent ~jitGuiRefresh / ~jitGuiRefreshOnce and ~jitSetNextSpec.
//  • Edit ops now call ~jitBuildAndNotify so GUI/CF mixer stay consistent.

(
// ====================================================
//   Utilities for working with the chain:
//   - Spec slicing & assembly
//   - Array-safe edit-ops (insert / remove / move)
//   - Setters for source/destination/stage parameters
//   - Stage info lookup (index or id)
//   - Introspection helpers
//   Load after: jit_chain_core_v3.scd (or your v3 core)
// ====================================================

// ---- Array helper (Array-safe removeAt via slicing) ----
~jitArrayRemoveAt = {
    var arr, index, n, idx;
    arg arr, index;
    n = arr.size;
    if(n <= 0) { [] }{
        idx = index.clip(0, n - 1);
        if(idx == 0) {
            if(n > 1) { arr.copyRange(1, n - 1) }{ [] }
        }{
            if(idx == (n - 1)) {
                arr.copyRange(0, n - 2)
            }{
                arr.copyRange(0, idx - 1) ++ arr.copyRange(idx + 1, n - 1)
            }
        }
    }
};

// ---- Listener / notifier (no eager broadcast on load) ----
~jitListeners = ~jitListeners ? Array.new;
~jitAddListener = { |fn| (~jitListeners.includes(fn)).if({ nil }, { ~jitListeners = ~jitListeners.add(fn) }) };
~jitRemoveListener = { |fn| ~jitListeners = ~jitListeners.reject(_ == fn) };

~jitNotify = { |phase, payload = nil|
    var arr;
    arr = (~jitListeners ? Array.new);
    arr.do { |fn| { fn.value(phase, payload) }.defer };
};

~jitNotifyWillBuild  = { |spec| ~jitNotify.(\willBuild, (spec: spec)) };
~jitNotifyDidBuild   = { |spec| ~jitNotify.(\didBuild,  (cur: spec, next: ~jitNextSpec)) };
~jitNotifyWillSwitch = { |from, to, fade, tail|
    var f, t;
    f = fade ? (~jitFadeTime ? 0.25);
    t = tail ? 0.0;
    ~jitNotify.(\willSwitch, (from: from, to: to, fade: f, tail: t))
};
~jitNotifyDidSwitch  = { |active, spec| ~jitNotify.(\didSwitch, (active: active, spec: spec)) };

// ---- Spec utilities ----
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

// ---- Edit operations (call ~jitBuildAndNotify to keep GUI/CF in sync) ----
~jitInsertStage = { |position, stageEntry|
    var spec, stages, pos, symArgs, sym, builder, newStages, newSpec;
    spec = (~jitCurrentSpec ? nil);
    if(spec.isNil) { "[WARN] ~jitInsertStage: no current spec.".warn; nil }{
        symArgs = ~jitNormalizeStage.(stageEntry);
        sym = symArgs[0];
        builder = (~fxBuilders ? nil);
        if((builder.isNil) or: { ~fxBuilders[sym].isNil }) {
            ("[WARN] ~jitInsertStage: unknown stage symbol " ++ sym.asString).warn; nil
        }{
            stages = ~jitSpecStages.(spec);
            pos = position.clip(0, stages.size);
            newStages = stages.insert(pos, stageEntry);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            (~jitBuildAndNotify.notNil).if({ ~jitBuildAndNotify.(newSpec) }, { ~jitBuild.(newSpec) })
        }
    }
};

~jitRemoveStage = { |which|
    var spec, stages, idx, newStages, newSpec;
    spec = (~jitCurrentSpec ? nil);
    if(spec.isNil) { "[WARN] ~jitRemoveStage: no current spec.".warn; nil }{
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
        if(idx.isNil) { ("[WARN] ~jitRemoveStage: stage not found: " ++ which.asString).warn; nil }{
            newStages = ~jitArrayRemoveAt.(stages, idx);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            (~jitBuildAndNotify.notNil).if({ ~jitBuildAndNotify.(newSpec) }, { ~jitBuild.(newSpec) })
        }
    }
};

~jitMoveStage = { |which, newPosition|
    var spec, stages, idx, entry, tmpStages, newIdx, newStages, newSpec;
    spec = (~jitCurrentSpec ? nil);
    if(spec.isNil) { "[WARN] ~jitMoveStage: no current spec.".warn; nil }{
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
        if(idx.isNil) { ("[WARN] ~jitMoveStage: stage not found: " ++ which.asString).warn; nil }{
            entry = stages[idx];
            tmpStages = ~jitArrayRemoveAt.(stages, idx);
            newIdx = newPosition.clip(0, tmpStages.size);
            newStages = tmpStages.insert(newIdx, entry);
            newSpec = ~jitSpecWithStages.(spec, newStages);
            (~jitBuildAndNotify.notNil).if({ ~jitBuildAndNotify.(newSpec) }, { ~jitBuild.(newSpec) })
        }
    }
};

// ---- Stage info and param flattening ----
~jitStagePrefixFor = (~jitStagePrefixFor ? ~jitStagePrefixFor);  // defined in core

~jitGetStageInfo = { |which|
    which.isNumber.if({
        var slot, arr;
        slot = which.asInteger;
        arr = (~jitStageIndexNodes ? []);
        if((slot < 0) or: { slot >= arr.size }) { nil }{
            (slot: slot, prefix: ((arr[slot] ?? { ("fx" ++ slot) })).asString)
        }
    },{
        ~jitStageIdInfo[which]
    })
};

~toKeyValueArray = { |params|
    var kv;
    if(params.isNil) { nil }{
        params.respondsTo(\keysValuesDo).if({
            kv = List.new; params.keysValuesDo { |k, v| kv.addAll([k, v]) }; kv.asArray
        },{
            params.isSequenceableCollection.if({ params.asArray },{ nil })
        })
    }
};

// ---- Setters ----
~jitSetFx = { |which, params|
    var info, prefix, kvPairs, rewritten;
    info = ~jitGetStageInfo.(which);
    if(info.isNil) { ("No such stage: " ++ which.asString).warn; nil }{
        prefix  = info[\prefix].asString;
        kvPairs = ~toKeyValueArray.(params);
        if(kvPairs.isNil) {
            ("~jitSetFx: params not understood for " ++ which.asString ++ " → " ++ params.asString).warn; nil
        }{
            rewritten = Array.new;
            kvPairs.clump(2).do { |kv|
                rewritten.addAll([ (prefix ++ "_" ++ kv[0].asString).asSymbol, kv[1] ]);
            };
            Ndef(\chain).set(*rewritten);
            info
        }
    }
};

~jitSetSource = { |params|
    var kvPairs;
    kvPairs = ~toKeyValueArray.(params);
    if(kvPairs.isNil) { "[WARN] ~jitSetSource: params not understood.".warn; nil }{ Ndef(\chain).set(*kvPairs) }
};

~jitSetDest = { |params|
    var kvPairs;
    kvPairs = ~toKeyValueArray.(params);
    if(kvPairs.isNil) { "[WARN] ~jitSetDest: params not understood.".warn; nil }{ Ndef(\out).set(*kvPairs) }
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

// ---- GUI helpers (silent) ----
~jitGuiRefresh = ~jitGuiRefresh ? {
    var curr, next;
    curr = (~jitCurrentSpec ? "nil");
    next = (~jitNextSpec ? "nil");
    if(~jitTmpGuiLabelCurrent.notNil) { ~jitTmpGuiLabelCurrent.string = "Current: " ++ curr.asString };
    if(~jitTmpGuiLabelNext.notNil)    { ~jitTmpGuiLabelNext.string    = "Next: "    ++ next.asString };
};

~jitGuiRefreshOnce = {
    var scheduled;
    scheduled = ~jitGuiRefreshScheduled ? false;
    if(scheduled.not) {
        ~jitGuiRefreshScheduled = true;
        { if(~jitGuiRefresh.notNil) { ~jitGuiRefresh.() }; ~jitGuiRefreshScheduled = false; }.defer;
    };
};

~jitSetNextSpec = ~jitSetNextSpec ? { |spec|
    var s;
    s = spec;
    ~jitNextSpec = s;
    ~jitGuiState = (~jitGuiState ? ());
    ~jitGuiState[\showNext] = true;
    ~jitNotify.(\preview, (next: s, cur: ~jitCurrentSpec));
    if(~jitGuiRefreshOnce.notNil) { ~jitGuiRefreshOnce.() };
};

// ---- CF-aware build/mixer keep-alive (helpers rely on v4 CF engine to do audio) ----
~jitCFEnsureMixer = ~jitCFEnsureMixer ? {
    var ft, tl;
    if(~jitCFEnabled == true) {
        ft = (~jitCF.notNil and: { ~jitCF[\fadeTime].notNil }).if({ ~jitCF[\fadeTime] }, { (~jitFadeTime ? 0.25) });
        tl = (~jitCF.notNil and: { ~jitCF[\tailHold].notNil }).if({ ~jitCF[\tailHold] }, { 0.0 });
        ~jitSetCrossfade.(ft, tl);  // re-install XFade2 on Ndef(\out) after ~jitBuild overwrote it
    };
};

~jitIsValidSpec = ~jitIsValidSpec ? { |spec|
    var ok, last;
    ok = spec.notNil and: { spec.isArray } and: { spec.size >= 2 } and: { spec.first == \guitar };
    ok = ok and: { last = spec.last; (last == \destination) or: { last == \destinationStereo } };
    ok
};

~jitBuildAndNotify = { |spec|
    var s, act;
    s = spec;
    if(~jitIsValidSpec.(s)) {
        ~jitNotifyWillBuild.(s);
        ~jitBuild.(s);
        if(~jitCFEnabled == true) {
            if(~jitBuildIntoChain.isFunction) {
                act = (~jitActiveChain ? \A);
                { ~jitBuildCF.(act, s) }.defer; // gentle defer to avoid /d_recv races
            };
            ~jitCFEnsureMixer.();
        };
        ~jitNotifyDidBuild.(s);
    }{
        ("[jit] ~jitBuildAndNotify: invalid spec — " ++ s.asString).warn; nil
    }
};

) // end block
