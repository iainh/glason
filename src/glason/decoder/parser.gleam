import glason/error
import glason/options
import glason/value.{type Value}
import glason/decoder/tokenizer.{type Token, tokenize}

pub fn parse(tokens: List(Token), decode_options: options.DecodeOptions) -> Result(Value, error.DecodeError) {
  let _ = tokens
  let _ = decode_options
  Error(error.not_implemented_decode_error())
}

pub fn parse_binary(input: String, decode_options: options.DecodeOptions) -> Result(Value, error.DecodeError) {
  let _ = decode_options
  case tokenize(input) {
    Ok(tokens) -> parse(tokens, decode_options)
    Error(e) -> Error(e)
  }
}
