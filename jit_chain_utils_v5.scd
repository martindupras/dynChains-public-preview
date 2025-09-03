
// jit_chain_utils_v5.scd
// Helper functions for chain building: normalization, ID extraction, prefixing

~jitNormalizeStage = { |entry|
    var sym, args, rest;
    sym = entry.isArray.if({ entry[0] }, { entry });
    args = [];
    if(entry.isArray and: { entry.size > 1 }) {
        rest = entry.copyRange(1, entry.size - 1);
        if(rest.size == 1 and: { rest[0].respondsTo(\keysValuesDo) }) {
            args = List.new;
            rest[0].keysValuesDo { |k, v| args.addAll([k, v]) };
            args = args.asArray;
        }{
            args = rest.flat;
        }
    };
    [sym, args]
};

~jitExtractIdAndDict = { |argsArray|
    var id, dict;
    id = nil;
    dict = IdentityDictionary.new;
    argsArray.clump(2).do { |kv|
        if(kv.size >= 2) {
            if(kv[0] == \id) { id = kv[1] } { dict[kv[0]] = kv[1] };
        }{
            ("Odd arg list; dropping trailing key %".format(kv[0])).warn;
        }
    };
    [id, dict]
};

~jitStagePrefixFor = { |slot, id|
    var base;
    base = id.isNil.if({ "fx" ++ slot }, { id.asString });
    base
};
