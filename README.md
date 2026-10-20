# toklen

[![CI](https://github.com/Esl1h/toklen/actions/workflows/ci.yml/badge.svg)](https://github.com/Esl1h/toklen/actions/workflows/ci.yml)

A [V](https://vlang.io) CLI that counts the real tokens in a file by sending it to whichever LLM is actually available, then estimates what it would cost across Anthropic's current models.

This is the first real consumer of [`vai`](https://github.com/Esl1h/vai)'s `Provider.complete()` against a live endpoint, not a mock: it exists to prove the module works end to end before building anything bigger on top of it.

## Install

```sh
v install https://github.com/Esl1h/vai   # dependency
git clone https://github.com/Esl1h/toklen
cd toklen
make build
```

## Usage

```sh
export ANTHROPIC_API_KEY=sk-ant-...
toklen path/to/file.md
```

Without `ANTHROPIC_API_KEY` set, `toklen` looks for a locally running [Ollama](https://ollama.com) and uses the first model it finds pulled:

```sh
ollama pull llama3.2:1b
toklen path/to/file.md
```

```
path/to/file.md: 532 tokens (via Ollama (llama3.2:1b))

Estimated cost if this were input to:
  claude-opus-5: $0.002660
  claude-sonnet-5: $0.001064
  claude-haiku-4-5: $0.000532
  claude-fable-5-1: $0.005320

(input-only estimate; assumes Ollama (llama3.2:1b)'s tokenizer is a reasonable
proxy for these models' tokenizers, which isn't exact across model families)
```

The request sent is `max_tokens: 1`, so this costs (or takes) about as little as a real call can: one token of output, whatever the file costs as input.

## Scope

No dedicated token-counting endpoint is called (`vai` doesn't have `Provider.count_tokens()` yet, see its own AGENTS.md). `toklen` gets a real count the only way currently available: a real completion call, reading `usage.input_tokens` back from whichever provider answered. The cost table is explicitly an estimate, not a guarantee: different model families use different tokenizers, so a count from Ollama's Llama tokenizer applied to Anthropic's pricing is an approximation, not a promise. This is stated in the tool's own output, not just this README.

## Development

```sh
make check   # fmt-check + vet + test
make test
make fmt
```

See AGENTS.md for a real V compiler bug this project ran into: on a machine where a checkout of `vai` itself sits next to this repo, `v test .` fails to resolve `vai`'s submodules (`vai.anthropic`, `vai.openai`) even though a normal build (`make build`) works fine. If `make test` fails with `unknown type` errors mentioning `vai.anthropic` or `vai.openai`, that's almost certainly this, not a real problem with the code, `make build` and a manual run are the way to verify in that case.

## License

MIT
