(
// shim: jit_chain_utils_patch_v2.scd
// Some v2 code may request this mis-ordered name. Forward to the correct one.
var here;
here = thisProcess.nowExecutingPath.dirname;
thisProcess.interpreter.executeFile(here ++ "/jit_chain_utils_v2_patch.scd");
("[jit] shim: jit_chain_utils_patch_v2 → jit_chain_utils_v2_patch").postln;
)
