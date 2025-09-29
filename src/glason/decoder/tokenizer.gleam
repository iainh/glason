import gleam/list
import gleam/option.{None}
import gleam/string
import gleam/int
import glason/error
import glason/value.{type Value, Null, Bool}

pub type Token {
  TokenValue(Value)
  TokenString(String)
  TokenNumber(String)
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

    [34, ..rest] ->
      case read_string(rest, position + 1, []) {
        Ok(#(value, remainder, next_position)) ->
          tokenize_codepoints(remainder, next_position, [TokenString(value), ..acc])

        Error(err) -> Error(err)
      }

    [45, ..rest] ->
      case read_number(rest, position + 1, [45], False) {
        Ok(#(lexeme, remainder, next_position)) ->
          tokenize_codepoints(remainder, next_position, [TokenNumber(lexeme), ..acc])

        Error(err) -> Error(err)
      }

    [codepoint, ..rest] ->
      case is_digit(codepoint) {
        True ->
          case read_number(rest, position + 1, [codepoint], True) {
            Ok(#(lexeme, remainder, next_position)) ->
              tokenize_codepoints(remainder, next_position, [TokenNumber(lexeme), ..acc])

            Error(err) -> Error(err)
          }

        False ->
          Error(unexpected_codepoint_error(codepoint, position))
      }
  }
}

fn read_string(
  codepoints: List(Int),
  current_position: Int,
  acc: List(Int),
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case codepoints {
    [] -> Error(unexpected_end_error(current_position))

    [34, ..rest] ->
      case reversed_ints_to_string(acc, current_position) {
        Ok(value) -> Ok(#(value, rest, current_position + 1))
        Error(err) -> Error(err)
      }

    [92, .._rest] ->
      Error(escape_not_supported_error(current_position))

    [codepoint, ..rest] ->
      read_string(rest, current_position + 1, [codepoint, ..acc])
  }
}

fn read_number(
  codepoints: List(Int),
  current_position: Int,
  acc: List(Int),
  has_digit: Bool,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case codepoints {
    [] -> finalize_number(acc, has_digit, [], current_position)

    [codepoint, ..rest] ->
      case is_digit(codepoint) {
        True -> read_number(rest, current_position + 1, [codepoint, ..acc], True)
        False -> finalize_number(acc, has_digit, [codepoint, ..rest], current_position)
      }
  }
}

fn finalize_number(
  acc: List(Int),
  has_digit: Bool,
  remainder: List(Int),
  next_position: Int,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case has_digit {
    True ->
      case reversed_ints_to_string(acc, next_position) {
        Ok(value) -> Ok(#(value, remainder, next_position))
        Error(err) -> Error(err)
      }

    False ->
      Error(number_format_error(next_position))
  }
}

fn is_digit(codepoint: Int) -> Bool {
  codepoint >= 48 && codepoint <= 57
}

fn unexpected_codepoint_error(codepoint: Int, position: Int) -> error.DecodeError {
  let message = "unexpected codepoint " <> int.to_string(codepoint)
  error.decode_error(error.UnexpectedByte(codepoint), message, position, None)
}

fn unexpected_end_error(position: Int) -> error.DecodeError {
  error.decode_error(error.UnexpectedEnd, "unexpected end of input", position, None)
}

fn escape_not_supported_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "string escape sequences not implemented",
    position,
    None,
  )
}

fn number_format_error(position: Int) -> error.DecodeError {
  error.decode_error(error.InvalidNumber, "invalid number literal", position, None)
}

fn reversed_ints_to_string(reversed: List(Int), position: Int) -> Result(String, error.DecodeError) {
  list.reverse(reversed)
  |> list.try_fold("", fn(acc, cp) {
    case string.utf_codepoint(cp) {
      Ok(parsed) ->
        Ok(string.append(acc, string.from_utf_codepoints([parsed])))

      Error(_) ->
        Error(
          error.decode_error(
            error.DecodeNotImplemented,
            "tokenizer encountered invalid unicode codepoint",
            position,
            None,
          ),
        )
    }
  })
}
