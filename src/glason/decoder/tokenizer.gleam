import glason/error
import glason/value.{type Value, Bool, Null}
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string

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

fn tokenize_codepoints(
  codepoints: List(Int),
  position: Int,
  acc: List(Token),
) -> Result(List(Token), error.DecodeError) {
  case codepoints {
    [] -> Ok(acc)
    [32, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [10, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [9, ..rest] -> tokenize_codepoints(rest, position + 1, acc)
    [13, ..rest] -> tokenize_codepoints(rest, position + 1, acc)

    [91, ..rest] ->
      tokenize_codepoints(rest, position + 1, [TokenStartArray, ..acc])
    [93, ..rest] ->
      tokenize_codepoints(rest, position + 1, [TokenEndArray, ..acc])
    [123, ..rest] ->
      tokenize_codepoints(rest, position + 1, [TokenStartObject, ..acc])
    [125, ..rest] ->
      tokenize_codepoints(rest, position + 1, [TokenEndObject, ..acc])
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
          tokenize_codepoints(remainder, next_position, [
            TokenString(value),
            ..acc
          ])

        Error(err) -> Error(err)
      }

    [45, ..rest] ->
      case read_number(rest, position + 1, [45], False, NumberInitial) {
        Ok(#(lexeme, remainder, next_position)) ->
          tokenize_codepoints(remainder, next_position, [
            TokenNumber(lexeme),
            ..acc
          ])

        Error(err) -> Error(err)
      }

    [codepoint, ..rest] ->
      case is_digit(codepoint) {
        True -> {
          let initial_state = digit_initial_state(codepoint)
          case
            read_number(rest, position + 1, [codepoint], True, initial_state)
          {
            Ok(#(lexeme, remainder, next_position)) ->
              tokenize_codepoints(remainder, next_position, [
                TokenNumber(lexeme),
                ..acc
              ])

            Error(err) -> Error(err)
          }
        }

        False -> Error(unexpected_codepoint_error(codepoint, position))
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

    [92, ..rest] ->
      case read_escape(rest, current_position + 1) {
        Ok(#(codepoint, remainder, next_position)) ->
          read_string(remainder, next_position, [codepoint, ..acc])

        Error(err) -> Error(err)
      }

    [codepoint, ..rest] ->
      read_string(rest, current_position + 1, [codepoint, ..acc])
  }
}

fn read_number(
  codepoints: List(Int),
  current_position: Int,
  acc: List(Int),
  has_digit: Bool,
  state: NumberState,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case codepoints {
    [] -> finalize_number(acc, has_digit, [], current_position, state)

    [codepoint, ..rest] ->
      case classify_number_char(codepoint) {
        Digit(digit) -> {
          let next_state = update_number_state_for_digit(state, digit)
          read_number(
            rest,
            current_position + 1,
            [digit, ..acc],
            True,
            next_state,
          )
        }

        Dot -> {
          let next_state = update_number_state_for_dot(state)
          case next_state {
            NumberInvalid ->
              finalize_number(
                acc,
                has_digit,
                [codepoint, ..rest],
                current_position,
                NumberInvalid,
              )
            _ ->
              read_number(
                rest,
                current_position + 1,
                [codepoint, ..acc],
                has_digit,
                next_state,
              )
          }
        }

        Exponent(exp) ->
          handle_exponent(rest, current_position, acc, has_digit, state, exp)

        Sign(sign) ->
          handle_exponent_sign(
            rest,
            current_position,
            acc,
            has_digit,
            state,
            sign,
          )

        Other(other) ->
          finalize_number(
            acc,
            has_digit,
            [other, ..rest],
            current_position,
            state,
          )
      }
  }
}

fn finalize_number(
  acc: List(Int),
  has_digit: Bool,
  remainder: List(Int),
  next_position: Int,
  state: NumberState,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case has_digit {
    True ->
      case state {
        NumberFractionStart -> Error(number_format_error(next_position))
        NumberExponentStart -> Error(number_format_error(next_position))
        NumberExponentSign -> Error(number_format_error(next_position))
        NumberInvalid -> Error(number_format_error(next_position))
        _ ->
          case reversed_ints_to_string(acc, next_position) {
            Ok(value) -> Ok(#(value, remainder, next_position))
            Error(err) -> Error(err)
          }
      }

    False -> Error(number_format_error(next_position))
  }
}

fn is_digit(codepoint: Int) -> Bool {
  codepoint >= 48 && codepoint <= 57
}

fn unexpected_codepoint_error(
  codepoint: Int,
  position: Int,
) -> error.DecodeError {
  let message = "unexpected codepoint " <> int.to_string(codepoint)
  error.decode_error(error.UnexpectedByte(codepoint), message, position, None)
}

fn unexpected_end_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.UnexpectedEnd,
    "unexpected end of input",
    position,
    None,
  )
}

fn number_format_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.InvalidNumber,
    "invalid number literal",
    position,
    None,
  )
}

fn digit_initial_state(codepoint: Int) -> NumberState {
  case codepoint {
    48 -> NumberLeadingZero
    _ -> NumberInteger
  }
}

fn update_number_state_for_digit(state: NumberState, digit: Int) -> NumberState {
  case state {
    NumberInitial -> digit_initial_state(digit)
    NumberLeadingZero -> NumberInvalid
    NumberInteger -> NumberInteger
    NumberFractionStart -> NumberFraction
    NumberFraction -> NumberFraction
    NumberExponentStart -> NumberExponent
    NumberExponentSign -> NumberExponent
    NumberExponent -> NumberExponent
    NumberInvalid -> NumberInvalid
  }
}

fn update_number_state_for_dot(state: NumberState) -> NumberState {
  case state {
    NumberLeadingZero -> NumberFractionStart
    NumberInteger -> NumberFractionStart
    _ -> NumberInvalid
  }
}

fn handle_exponent(
  codepoints: List(Int),
  position: Int,
  acc: List(Int),
  has_digit: Bool,
  state: NumberState,
  codepoint: Int,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case state {
    NumberInteger ->
      read_number(
        codepoints,
        position + 1,
        [codepoint, ..acc],
        has_digit,
        NumberExponentStart,
      )

    NumberLeadingZero ->
      read_number(
        codepoints,
        position + 1,
        [codepoint, ..acc],
        has_digit,
        NumberExponentStart,
      )

    NumberFraction ->
      read_number(
        codepoints,
        position + 1,
        [codepoint, ..acc],
        has_digit,
        NumberExponentStart,
      )

    _ ->
      finalize_number(
        acc,
        has_digit,
        [codepoint, ..codepoints],
        position,
        NumberInvalid,
      )
  }
}

fn handle_exponent_sign(
  codepoints: List(Int),
  position: Int,
  acc: List(Int),
  has_digit: Bool,
  state: NumberState,
  sign: Int,
) -> Result(#(String, List(Int), Int), error.DecodeError) {
  case state {
    NumberExponentStart ->
      read_number(
        codepoints,
        position + 1,
        [sign, ..acc],
        has_digit,
        NumberExponentSign,
      )

    _ ->
      finalize_number(
        acc,
        has_digit,
        [sign, ..codepoints],
        position,
        NumberInvalid,
      )
  }
}

type NumberState {
  NumberInitial
  NumberLeadingZero
  NumberInteger
  NumberFractionStart
  NumberFraction
  NumberExponentStart
  NumberExponentSign
  NumberExponent
  NumberInvalid
}

type NumberChar {
  Digit(Int)
  Dot
  Exponent(Int)
  Sign(Int)
  Other(Int)
}

fn read_escape(
  codepoints: List(Int),
  position: Int,
) -> Result(#(Int, List(Int), Int), error.DecodeError) {
  case codepoints {
    [] -> Error(unexpected_end_error(position))

    [34, ..rest] -> Ok(#(34, rest, position + 1))
    [92, ..rest] -> Ok(#(92, rest, position + 1))
    [47, ..rest] -> Ok(#(47, rest, position + 1))
    [98, ..rest] -> Ok(#(8, rest, position + 1))
    [102, ..rest] -> Ok(#(12, rest, position + 1))
    [110, ..rest] -> Ok(#(10, rest, position + 1))
    [114, ..rest] -> Ok(#(13, rest, position + 1))
    [116, ..rest] -> Ok(#(9, rest, position + 1))

    [117, ..rest] ->
      case rest {
        [a, b, c, d, ..tail] ->
          decode_unicode_escape([a, b, c, d], tail, position + 5)
        _ -> Error(unexpected_end_error(position))
      }

    [codepoint, ..] -> Error(invalid_escape_error(codepoint, position))
  }
}

fn decode_unicode_escape(
  digits: List(Int),
  rest: List(Int),
  next_position: Int,
) -> Result(#(Int, List(Int), Int), error.DecodeError) {
  case hex_digits_to_int(digits) {
    Ok(codepoint) ->
      case is_high_surrogate(codepoint) {
        True -> decode_surrogate_pair(codepoint, rest, next_position)
        False ->
          case is_low_surrogate(codepoint) {
            True -> Error(unexpected_low_surrogate_error(next_position - 4))
            False -> Ok(#(codepoint, rest, next_position))
          }
      }

    Error(_) -> Error(invalid_unicode_escape_error(next_position - 4))
  }
}

fn decode_surrogate_pair(
  high: Int,
  rest: List(Int),
  next_position: Int,
) -> Result(#(Int, List(Int), Int), error.DecodeError) {
  case rest {
    [92, 117, a, b, c, d, ..tail] ->
      case hex_digits_to_int([a, b, c, d]) {
        Ok(low) ->
          case is_low_surrogate(low) {
            True ->
              Ok(#(combine_surrogates(high, low), tail, next_position + 6))

            False -> Error(invalid_surrogate_pair_error(next_position - 4))
          }

        Error(_) -> Error(invalid_unicode_escape_error(next_position + 1))
      }

    _ -> Error(unpaired_high_surrogate_error(next_position - 4))
  }
}

fn is_high_surrogate(codepoint: Int) -> Bool {
  codepoint >= 0xD800 && codepoint <= 0xDBFF
}

fn is_low_surrogate(codepoint: Int) -> Bool {
  codepoint >= 0xDC00 && codepoint <= 0xDFFF
}

fn combine_surrogates(high: Int, low: Int) -> Int {
  let high_bits = high - 0xD800
  let low_bits = low - 0xDC00
  0x10000 + high_bits * 0x400 + low_bits
}

fn hex_digits_to_int(digits: List(Int)) -> Result(Int, Nil) {
  hex_digits_to_int_loop(digits, 0)
}

fn hex_digits_to_int_loop(digits: List(Int), acc: Int) -> Result(Int, Nil) {
  case digits {
    [] -> Ok(acc)
    [digit, ..rest] ->
      case hex_value(digit) {
        Ok(value) -> hex_digits_to_int_loop(rest, acc * 16 + value)
        Error(_) -> Error(Nil)
      }
  }
}

fn hex_value(codepoint: Int) -> Result(Int, Nil) {
  case codepoint {
    cp if cp >= 48 && cp <= 57 -> Ok(cp - 48)
    cp if cp >= 65 && cp <= 70 -> Ok(cp - 55)
    cp if cp >= 97 && cp <= 102 -> Ok(cp - 87)
    _ -> Error(Nil)
  }
}

fn invalid_escape_error(codepoint: Int, position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "invalid escape sequence: " <> int.to_string(codepoint),
    position,
    None,
  )
}

fn invalid_unicode_escape_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "invalid unicode escape",
    position,
    None,
  )
}

fn unpaired_high_surrogate_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "high surrogate not followed by low surrogate",
    position,
    None,
  )
}

fn unexpected_low_surrogate_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "low surrogate without preceding high surrogate",
    position,
    None,
  )
}

fn invalid_surrogate_pair_error(position: Int) -> error.DecodeError {
  error.decode_error(
    error.DecodeNotImplemented,
    "invalid surrogate pair",
    position,
    None,
  )
}

fn reversed_ints_to_string(
  reversed: List(Int),
  position: Int,
) -> Result(String, error.DecodeError) {
  list.reverse(reversed)
  |> list.try_fold("", fn(acc, cp) {
    case string.utf_codepoint(cp) {
      Ok(parsed) -> Ok(string.append(acc, string.from_utf_codepoints([parsed])))

      Error(_) ->
        Error(error.decode_error(
          error.DecodeNotImplemented,
          "tokenizer encountered invalid unicode codepoint",
          position,
          None,
        ))
    }
  })
}

fn classify_number_char(codepoint: Int) -> NumberChar {
  case codepoint {
    46 -> Dot
    101 -> Exponent(codepoint)
    69 -> Exponent(codepoint)
    43 -> Sign(codepoint)
    45 -> Sign(codepoint)
    other -> classify_digit_or_other(other)
  }
}

fn classify_digit_or_other(codepoint: Int) -> NumberChar {
  case is_digit(codepoint) {
    True -> Digit(codepoint)
    False -> Other(codepoint)
  }
}
