import gleam/int
import gleam/option.{None}
import glason/error
import glason/options
import glason/value
import glason/decoder/tokenizer.{
  type Token,
  tokenize,
  TokenValue,
  TokenString,
  TokenNumber,
  TokenStartArray,
  TokenEndArray,
  TokenStartObject,
  TokenEndObject,
  TokenColon,
  TokenComma,
}

pub fn parse(tokens: List(Token), _decode_options: options.DecodeOptions) -> Result(value.Value, error.DecodeError) {
  case tokens {
    [token] -> token_to_value(token)
    [] -> Error(empty_input_error())
    _ -> Error(complex_structure_error())
  }
}

pub fn parse_binary(input: String, decode_options: options.DecodeOptions) -> Result(value.Value, error.DecodeError) {
  let _ = decode_options
  case tokenize(input) {
    Ok(tokens) -> parse(tokens, decode_options)
    Error(e) -> Error(e)
  }
}

fn token_to_value(token: Token) -> Result(value.Value, error.DecodeError) {
  case token {
    TokenValue(inner) -> Ok(inner)

    TokenString(text) -> Ok(value.String(text))

    TokenNumber(text) ->
      case int.parse(text) {
        Ok(number) -> Ok(value.Int(number))
        Error(_) -> Error(number_not_supported_error())
      }

    TokenStartArray -> Error(complex_structure_error())
    TokenEndArray -> Error(complex_structure_error())
    TokenStartObject -> Error(complex_structure_error())
    TokenEndObject -> Error(complex_structure_error())
    TokenColon -> Error(complex_structure_error())
    TokenComma -> Error(complex_structure_error())
  }
}

fn empty_input_error() -> error.DecodeError {
  error.decode_error(error.UnexpectedEnd, "no tokens produced for input", 0, None)
}

fn complex_structure_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "parsing for complex JSON structures not implemented",
    0,
    None,
  )
}

fn number_not_supported_error() -> error.DecodeError {
  error.decode_error(error.InvalidNumber, "number format not yet supported", 0, None)
}
