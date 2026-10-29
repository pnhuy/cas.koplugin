-- Explicit resource limits shared by the CAS and plotting engines.
-- Exceeding a limit yields a `too_complex` error, never a hang or a crash.

return {
    max_chars = 500,
    max_depth = 50,
    max_nodes = 2000,
    max_terms = 500,
    max_evals = 4000,
    refine_depth = 8,
    max_functions = 6,
}
