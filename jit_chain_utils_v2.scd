// jit_chain_utils_v2.scd
// MD 20250829

(
/* ====================================================
   Utilities for working with the chain:
   - Spec slicing & assembly
   - Array-safe edit-ops (insert / remove / move)
   - Setters for source/destination/stage parameters
   - Stage info lookup (index or id)
   - Introspection helpers
   Load after: jit_chain_core_v2.scd
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

// Whenever you rebuild or switch:
(~jitListeners ? []).do { |fn| fn.value(\didBuild, (cur: ~jitCurrentSpec, next: ~jitNextSpec)) };


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
)
