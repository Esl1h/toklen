// toklen counts real tokens in a file by sending it to whichever LLM is
// actually configured (Anthropic if ANTHROPIC_API_KEY is set, otherwise
// the first model Ollama has pulled locally) with max_tokens: 1, then
// reads the real input token count back from usage.input_tokens. It is
// the first real consumer of vai's Provider.complete() against a live
// endpoint, not just a mock.
module main

import json2
import net.http

const ollama_base = 'http://localhost:11434'

// parse_first_model_name is split out from the HTTP call so it's
// testable with a fixture, without needing Ollama actually running.
fn parse_first_model_name(body string) !string {
	val := json2.decode[json2.Any](body)!
	if val !is map[string]json2.Any {
		return error('expected a JSON object from Ollama')
	}
	obj := val.as_map()
	models_val := obj['models'] or { return error('no "models" field in Ollama response') }
	models := models_val.as_array()
	if models.len == 0 {
		return error('Ollama has no models pulled (try: ollama pull llama3.2:1b)')
	}
	first := models[0].as_map()
	name_val := first['name'] or { return error('a model entry has no "name" field') }
	return name_val.str()
}

fn ollama_first_model() !string {
	resp := http.get('${ollama_base}/api/tags') or {
		return error('Ollama not reachable at ${ollama_base}: ${err}')
	}
	if resp.status_code != 200 {
		return error('Ollama returned HTTP ${resp.status_code}')
	}
	return parse_first_model_name(resp.body)
}
