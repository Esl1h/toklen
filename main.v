module main

import os
import vai
import vai.anthropic
import vai.openai

const anthropic_models = ['claude-opus-5', 'claude-sonnet-5', 'claude-haiku-4-5', 'claude-fable-5-1']!

fn main() {
	if os.args.len < 2 {
		eprintln('usage: toklen <file>')
		exit(1)
	}
	path := os.args[1]
	content := os.read_file(path) or {
		eprintln('error: ${err}')
		exit(1)
	}

	req := vai.Request{
		messages:   [vai.user(content)]
		max_tokens: 1
	}

	mut resp := vai.Response{}
	mut label := ''

	anthropic_key := os.getenv('ANTHROPIC_API_KEY')
	if anthropic_key != '' {
		model := 'claude-sonnet-5'
		p := anthropic.Provider{
			api_key: anthropic_key
		}
		mut r := req
		r.model = model
		resp = p.complete(r) or {
			eprintln('anthropic error: ${err}')
			exit(1)
		}
		label = 'Anthropic (${model})'
	} else {
		model := ollama_first_model() or {
			eprintln('error: ${err}')
			eprintln('set ANTHROPIC_API_KEY, or run `ollama pull <model>` first')
			exit(1)
		}
		p := openai.Provider{
			base_url: '${ollama_base}/v1'
		}
		mut r := req
		r.model = model
		resp = p.complete(r) or {
			eprintln('ollama error: ${err}')
			exit(1)
		}
		label = 'Ollama (${model})'
	}

	tokens := resp.usage.input_tokens
	if tokens == 0 {
		// a real file is at least one token; zero means the response
		// carried no usage and the count (and cost table below) is not
		// real.
		eprintln('warning: provider reported zero input tokens; the response may not have carried usage')
	}
	println('${path}: ${tokens} tokens (via ${label})')
	println('')
	println('Estimated cost if this were input to:')
	for m in anthropic_models {
		c := vai.cost(m, vai.Usage{
			input_tokens: tokens
		})
		if c.unknown {
			println('  ${m}: unpriced (not in vai cost table)')
		} else {
			println('  ${m}: \$${c.input:.6f}')
		}
	}
	println('')
	println("(input-only estimate; assumes ${label}'s tokenizer is a reasonable proxy for these models' tokenizers, which isn't exact across model families)")
}
