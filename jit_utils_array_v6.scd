// jit_utils_array_v6.scd
// Array-safe utility operations for chain editing.

(
    ~jitArrayRemoveAt = { |arr, index|
        var n = arr.size, idx;
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
)