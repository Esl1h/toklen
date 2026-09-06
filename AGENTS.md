# AGENTS.md

Instructions for coding agents working in this repository.

## What this project is

`toklen` is a V CLI: it sends a file to whichever LLM is actually
configured (Anthropic if `ANTHROPIC_API_KEY` is set, otherwise the first
model Ollama has pulled locally) with `max_tokens: 1`, reads the real
input token count back from `usage.input_tokens`, and estimates cost
across Anthropic's pricing table via `vai.cost()`. It is the first real
consumer of `vai`'s `Provider.complete()` against a live endpoint, every
test in `vai` itself runs against a mock, by design; this is where that
gets proven against something real.

## V is under-represented in your training data, verify, never guess

Same standing rule as `vai`, `redact`, `vjsonrpc`, `ccstat`. Compile after
every meaningful change. For this repo specifically, "compile" means
`make build` (`v -o toklen .`), not `v test .`, see the bug below.

## A real, reproduced V compiler bug, do not "fix" the code for it

**`v test .` fails in this repository specifically because a checkout of
`vai` (this project's own dependency) happens to sit right next to
`toklen` on this machine** (`~/GIT/vai` next to `~/GIT/toklen`). The
error looks like a real code problem, `unknown type
vai.anthropic.Provider`, `unknown type vai.openai.Provider`, cascading
into nonsense "assignment mismatch" and "unexpected or block" errors on
every line that uses either type, but the code is fine.

Root cause, confirmed by isolated reproduction (not guessed): V's test
runner compiles each `_test.v` file as if it were the sole entry point
passed to `v` (documented behavior, see V's own docs on `_test.v` files
being compiled as separate programs). When that happens in a directory
whose `v.mod` depends on an external module (`vai`) via VPM install, AND
a *sibling directory on disk* happens to share that module's exact name
(`~/GIT/vai`) and also has its own `v.mod`, V's import resolution gets
confused between the VPM-installed copy (`~/.vmodules/vai`) and the
sibling. The confusion is selective: `import vai` (the root import)
still resolves fine, `vai.Request`, `vai.user`, `vai.cost`, `vai.Usage`
all work, but `import vai.anthropic` / `import vai.openai` (submodule
imports) silently fail to resolve, as if the type were never declared.

Reproduced in isolation, twice: once by copying this repo's exact files
into a scratch directory with a full copy of `vai` as a sibling (fails,
identical error), and once by copying the same files next to an *empty*
directory merely named `vai` (passes, so it's not just the name, it's
having a real `v.mod`-bearing module there). A scratch copy with no
`vai`-named sibling at all also passes. `make build` (`v -o toklen .`,
compiling the whole directory as one unit, not per-file) is unaffected
either way, the bug is specific to the per-file compilation `v test .`
performs internally.

**Do not**:
- "Fix" this by removing the `import vai.anthropic` / `import vai.openai`
  lines, adding fake usages, restructuring which file owns the import, or
  merging files together. All of these were tried during the
  investigation and none of them changed the outcome, the bug is
  filesystem-layout-dependent, not code-shape-dependent.
- Assume this is broken everywhere. It is very likely fine on CI or any
  machine that doesn't happen to have a `vai` checkout sitting next to
  this repo. If you hit it, verify with `make build` first before
  concluding the code itself is wrong.
- Report a code regression from this. If `v test .` starts failing this
  way, check whether a `vai` directory has appeared as a sibling before
  assuming the source changed.

If this needs to be fixed for real (not worked around), it belongs in an
upstream V bug report, not a workaround in this repo's source.

## Gotchas found in this codebase

- `json2.Any` map access needs the same `or {}` / `if v := m[key] {}`
  discipline every other project here found, see `parse_first_model_name`
  in `ollama.v`.
- V vet prefers a fixed-size array for a const with a known, unchanging
  element count: `[a, b, c, d]!`, not `[a, b, c, d]`. See
  `anthropic_models` in `main.v`.
- Clearing V's build cache (`rm -rf /tmp/v_1000 ~/.cache/v`) can trigger a
  one-time self-rebuild of the V compiler itself on the next invocation
  (visible as `vlib/strconv`/`vlib/hash` warnings and a spurious "No input
  .v files" error on that first run only). Retry once before assuming
  something is actually broken.

## Design decisions worth knowing before changing scope

- **No `count_tokens()` endpoint call.** `vai` doesn't have one yet (see
  its own AGENTS.md). Getting a real count today means a real completion
  call with `max_tokens: 1`, cheap, but not free, and not instant. This
  is a deliberate stand-in, not the intended long-term design; swap it
  for `Provider.count_tokens()` once that exists in `vai`, rather than
  building a second code path alongside it.
- **Ollama auto-detection picks the *first* model `/api/tags` returns**,
  not the "best" one by any measure. There is exactly one use case here
  (a quick local test target), not a model-selection feature, don't
  build ranking/preference logic without a real reason to.
- **The cost table is explicitly labeled an estimate, in the tool's own
  output, not just in docs.** Different model families tokenize
  differently; showing Ollama's Llama token count against Anthropic
  pricing without that caveat would be a genuinely misleading claim, not
  a rounding error.

## Build and test

```sh
make build   # v -o toklen .  , the real verification for this repo
make check   # fmt-check + vet + test, test step may fail, see above
make fmt     # v fmt -w .
```

## Do not

- Add a dependency beyond `vai`.
- Build a general-purpose "which provider is configured" abstraction here
 , this tool only ever needs to try Anthropic then Ollama, in that
  order. If a third provider is ever wanted, reconsider then, not now.
