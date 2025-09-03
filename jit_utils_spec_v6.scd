// jit_utils_spec_v6.scd
// Spec slicing, assembly, and stage edit-ops.

(
    ~jitSpecStages = { |spec| (spec.size > 2).if({ spec.copyRange(1, spec.size - 2) }, { [] }) };
    ~jitSpecWithStages = { |spec, newStages| [spec.first] ++ newStages ++ [spec.last] };

    ~jitInsertStage = { |position, stageEntry|
        var spec = (~jitCurrentSpec ? nil);
        (spec.isNil).if({
            "[WARN] ~jitInsertStage: no current spec.".warn; nil
        },{
            var symArgs = ~jitNormalizeStage.(stageEntry);
            var sym = symArgs[0];
            var builder = (~fxBuilders ? nil);
            ((builder.isNil) or: { ~fxBuilders[sym].isNil }).if({
                ("[WARN] ~jitInsertStage: unknown stage symbol " ++ sym.asString).warn; nil
            },{
                var stages = ~jitSpecStages.(spec);
                var pos = position.clip(0, stages.size);
                var newStages = stages.insert(pos, stageEntry);
                var newSpec = ~jitSpecWithStages.(spec, newStages);
                ~jitBuild.(newSpec)
            })
        })
    };

    ~jitRemoveStage = { |which|
        var spec = (~jitCurrentSpec ? nil);
        (spec.isNil).if({
            "[WARN] ~jitRemoveStage: no current spec.".warn; nil
        },{
            var stages = ~jitSpecStages.(spec);
            var idx = which.isNumber.if({
                which.asInteger.clip(0, stages.size - 1)
            },{
                var targetId = which;
                stages.detectIndex { |entry|
                    var symArgs = ~jitNormalizeStage.(entry);
                    var idAndDict = ~jitExtractIdAndDict.(symArgs[1]);
                    idAndDict[0] == targetId
                }
            });
            (idx.isNil).if({
                ("[WARN] ~jitRemoveStage: stage not found: " ++ which.asString).warn; nil
            },{
                var newStages = ~jitArrayRemoveAt.(stages, idx);
                var newSpec = ~jitSpecWithStages.(spec, newStages);
                ~jitBuild.(newSpec)
            })
        })
    };

    ~jitMoveStage = { |which, newPosition|
        var spec = (~jitCurrentSpec ? nil);
        (spec.isNil).if({
            "[WARN] ~jitMoveStage: no current spec.".warn; nil
        },{
            var stages = ~jitSpecStages.(spec);
            var idx = which.isNumber.if({
                which.asInteger.clip(0, stages.size - 1)
            },{
                var targetId = which;
                stages.detectIndex { |entry|
                    var symArgs = ~jitNormalizeStage.(entry);
                    var idAndDict = ~jitExtractIdAndDict.(symArgs[1]);
                    idAndDict[0] == targetId
                }
            });
            (idx.isNil).if({
                ("[WARN] ~jitMoveStage: stage not found: " ++ which.asString).warn; nil
            },{
                var entry = stages[idx];
                var tmpStages = ~jitArrayRemoveAt.(stages, idx);
                var newIdx = newPosition.clip(0, tmpStages.size);
                var newStages = tmpStages.insert(newIdx, entry);
                var newSpec = ~jitSpecWithStages.(spec, newStages);
                ~jitBuild.(newSpec)
            })
        })
    };
)