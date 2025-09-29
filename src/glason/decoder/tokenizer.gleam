import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import glason/error
import glason/value.{type Value, Null, Bool}

pub type Token {
  TokenValue(Value)
  TokenStartArray
  TokenEndArray
  TokenStartObject
  TokenEndObject
  TokenColon
  TokenComma
}

pub fn tokenize(input: String) -> Result(List(Token), error.DecodeError) {
  let codepoints =
    string.to_utf_codepoints(input)
    |> list.map(string.utf_codepoint_to_int)

  case tokenize_codepoints(codepoints, 0, []) {
    Ok(tokens) -> Ok(list.reverse(tokens))
    Error(err) -> Error(err)
  }
}

fn tokenize_codepoints(codepoints: List(Int), position: Int, acc: List(Token)) -> Result(List(Token), error.DecodeError) {
  case codepoints {
    [] -> Ok(acc)
    [32, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [10, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [9, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [13, ..rest] -> tokenize_codepoints(rest, position + 1, acc)

    [91, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenStartArray, ..acc])
    [93, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenEndArray, ..acc])
    [123, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenStartObject, ..acc])
    [125, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenEndObject, ..acc])
    [44, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenComma, ..acc])
    [58, ..rest] -> tokenize_codepoints(rest, position + 1, [TokenColon, ..acc])

    [110, 117, 108, 108, ..rest] ->
      tokenize_codepoints(rest, position + 4, [TokenValue(Null), ..acc])

    [116, 114, 117, 101, ..rest] ->
      tokenize_codepoints(rest, position + 4, [TokenValue(Bool(True)), ..acc])

    [102, 97, 108, 115, 101, ..rest] ->
      tokenize_codepoints(rest, position + 5, [TokenValue(Bool(False)), ..acc])

    [codepoint, .._rest] ->
      Error(unexpected_codepoint_error(codepoint, position))
  }
}

fn unexpected_codepoint_error(codepoint: Int, position: Int) -> error.DecodeError {
  let message = "unexpected codepoint " <> int.to_string(codepoint)
  error.decode_error(error.UnexpectedByte(codepoint), message, position, None)
}
