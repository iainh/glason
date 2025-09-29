import gleam/int
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
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
  TokenComma,
  TokenColon,
}

pub fn parse(tokens: List(Token), _decode_options: options.DecodeOptions) -> Result(value.Value, error.DecodeError) {
  case parse_value(tokens) {
    Ok(#(result, [])) -> Ok(result)
    Ok(#(_result, _rest)) -> Error(extra_tokens_error())
    Error(err) -> Error(err)
  }
}

pub fn parse_binary(input: String, decode_options: options.DecodeOptions) -> Result(value.Value, error.DecodeError) {
  let _ = decode_options
  case tokenize(input) {
    Ok(tokens) -> parse(tokens, decode_options)
    Error(e) -> Error(e)
  }
}

fn parse_value(tokens: List(Token)) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case tokens {
    [] -> Error(empty_input_error())
    [TokenValue(inner), ..rest] -> Ok(#(inner, rest))
    [TokenString(text), ..rest] -> Ok(#(value.String(text), rest))
    [TokenNumber(text), ..rest] -> parse_number(text, rest)
    [TokenStartArray, ..rest] -> parse_array(rest, [])
    [TokenStartObject, ..rest] -> parse_object(rest, [])
    [token, .._] -> Error(unexpected_token_error(token))
  }
}

fn parse_number(text: String, rest: List(Token)) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case int.parse(text) {
    Ok(number) -> Ok(#(value.Int(number), rest))
    Error(_) ->
      case parse_float_value(text) {
        Ok(f) -> Ok(#(value.Float(f), rest))
        Error(_) -> Error(number_not_supported_error())
      }
  }
}

fn empty_input_error() -> error.DecodeError {
  error.decode_error(error.UnexpectedEnd, "no tokens produced for input", 0, None)
}

fn extra_tokens_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "additional tokens found after parsing value",
    0,
    None,
  )
}

fn number_not_supported_error() -> error.DecodeError {
  error.decode_error(error.InvalidNumber, "number format not yet supported", 0, None)
}

fn unexpected_token_error(_token: Token) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "unexpected token encountered",
    0,
    None,
  )
}

fn parse_object(tokens: List(Token), acc: List(#(String, value.Value))) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case tokens {
    [] -> Error(empty_input_error())
    [TokenEndObject, ..rest] ->
      Ok(#(value.Object(list.reverse(acc)), rest))
    [TokenString(key), ..rest] ->
      parse_object_colon(rest, key, acc)
    [TokenValue(value.String(key)), ..rest] ->
      parse_object_colon(rest, key, acc)
    _ -> Error(object_key_error())
  }
}

fn parse_object_colon(
  tokens: List(Token),
  key: String,
  acc: List(#(String, value.Value)),
) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case tokens {
    [TokenColon, ..rest] ->
      case parse_value(rest) {
        Ok(#(val, after_value)) ->
          parse_object_after_value(after_value, key, val, acc)
        Error(err) -> Error(err)
      }
    _ -> Error(object_colon_error())
  }
}

fn parse_object_after_value(
  tokens: List(Token),
  key: String,
  val: value.Value,
  acc: List(#(String, value.Value)),
) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  let updated = [#(key, val), ..acc]
  case tokens {
    [TokenComma, ..rest] -> parse_object(rest, updated)
    [TokenEndObject, ..rest] ->
      Ok(#(value.Object(list.reverse(updated)), rest))
    [] -> Error(empty_input_error())
    _ -> Error(object_separator_error())
  }
}

fn parse_array(tokens: List(Token), acc: List(value.Value)) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case tokens {
    [] -> Error(empty_input_error())

    [TokenEndArray, ..rest] ->
      Ok(#(value.Array(list.reverse(acc)), rest))

    _ ->
      case parse_value(tokens) {
        Ok(#(element, rest)) ->
          parse_array_after_element(rest, [element, ..acc])
        Error(err) -> Error(err)
      }
  }
}

fn parse_array_after_element(tokens: List(Token), acc: List(value.Value)) -> Result(#(value.Value, List(Token)), error.DecodeError) {
  case tokens {
    [] -> Error(empty_input_error())

    [TokenComma, ..rest] ->
      case parse_value(rest) {
        Ok(#(element, remainder)) ->
          parse_array_after_element(remainder, [element, ..acc])
        Error(err) -> Error(err)
      }

    [TokenEndArray, ..rest] ->
      Ok(#(value.Array(list.reverse(acc)), rest))

    [_token, .._] ->
      Error(array_separator_error())
  }
}

fn array_separator_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "expected comma or closing bracket in array",
    0,
    None,
  )
}

fn object_key_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "expected string key in object",
    0,
    None,
  )
}

fn object_colon_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "expected colon after object key",
    0,
    None,
  )
}

fn object_separator_error() -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "expected comma or closing brace in object",
    0,
    None,
  )
}

fn parse_float_value(text: String) -> Result(Float, Nil) {
  case float.parse(text) {
    Ok(f) -> Ok(f)
    Error(_) ->
      case ensure_decimal_in_exponent(text) {
        Some(adjusted) -> float.parse(adjusted)
        None -> Error(Nil)
      }
  }
}

fn ensure_decimal_in_exponent(text: String) -> Option(String) {
  case split_exponent(text, "e") {
    Some(#(before, after)) -> Some(build_exponent_string(before, after))
    None ->
      case split_exponent(text, "E") {
        Some(#(before, after)) -> Some(build_exponent_string(before, after))
        None -> None
      }
  }
}

fn split_exponent(text: String, marker: String) -> Option(#(String, String)) {
  case string.split_once(text, marker) {
    Ok(#(before, after)) -> Some(#(before, after))
    Error(_) -> None
  }
}

fn build_exponent_string(before: String, after: String) -> String {
  let base =
    case string.contains(before, ".") {
      True -> before
      False -> string.concat([before, ".0"])
    }

  string.concat([base, "e", after])
}
