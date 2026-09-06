module main

import vai.anthropic
import vai.openai

fn test_parse_first_model_name() {
	body := '{"models":[{"name":"llama3.2:1b","model":"llama3.2:1b","size":1321098329}]}'
	name := parse_first_model_name(body) or {
		assert false, err.msg()
		return
	}
	assert name == 'llama3.2:1b'
}

fn test_parse_first_model_name_empty_list() {
	if _ := parse_first_model_name('{"models":[]}') {
		assert false, 'expected an error'
	}
}

fn test_parse_first_model_name_not_json() {
	if _ := parse_first_model_name('not json') {
		assert false, 'expected an error'
	}
}

fn test_parse_first_model_name_rejects_models_not_array() {
	// json2's as_array() silently wraps a non-array value (null becomes
	// [null]), which used to land in an unrelated "no name field" error.
	if _ := parse_first_model_name('{"models":null}') {
		assert false, 'expected an error'
	} else {
		assert err.msg() == '"models" must be an array', err.msg()
	}
	if _ := parse_first_model_name('{"models":"llama"}') {
		assert false, 'expected an error'
	} else {
		assert err.msg() == '"models" must be an array', err.msg()
	}
}

fn test_parse_first_model_name_rejects_entry_not_object() {
	if _ := parse_first_model_name('{"models":[42]}') {
		assert false, 'expected an error'
	} else {
		assert err.msg() == 'a model entry is not an object', err.msg()
	}
}

fn test_parse_first_model_name_rejects_name_not_string() {
	if _ := parse_first_model_name('{"models":[{"name":42}]}') {
		assert false, 'expected an error'
	} else {
		assert err.msg() == 'a model entry "name" is not a string', err.msg()
	}
}
