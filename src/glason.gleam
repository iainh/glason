import glason/decoder/parser
import glason/encoder/builder
import glason/error
import glason/options
import glason/value.{type Value}
import gleam/bit_array
import gleam/bytes_builder as bb
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn decode(input: String) -> Result(Value, error.DecodeError) {
  decode_with(input, options.default_decode_options())
}

pub fn decode_with(
  input: String,
  decode_options: options.DecodeOptions,
) -> Result(Value, error.DecodeError) {
  parser.parse_binary(remove_bom(input), decode_options)
}

pub fn decode_binary(input: BitArray) -> Result(Value, error.DecodeError) {
  decode_binary_with(input, options.default_decode_options())
}

pub fn decode_binary_with(
  input: BitArray,
  decode_options: options.DecodeOptions,
) -> Result(Value, error.DecodeError) {
  prepare_bits(input)
  |> result.then(fn(text) { parser.parse_binary(text, decode_options) })
}

pub fn decode_iodata(input: List(BitArray)) -> Result(Value, error.DecodeError) {
  decode_iodata_with(input, options.default_decode_options())
}

pub fn decode_iodata_with(
  input: List(BitArray),
  decode_options: options.DecodeOptions,
) -> Result(Value, error.DecodeError) {
  bit_array.concat(input)
  |> prepare_bits
  |> result.then(fn(text) { parser.parse_binary(text, decode_options) })
}

pub fn encode(value: Value) -> Result(String, error.EncodeError) {
  encode_with(value, options.default_encode_options())
}

pub fn encode_with(
  value: Value,
  encode_options: options.EncodeOptions,
) -> Result(String, error.EncodeError) {
  case builder.build(value, encode_options) {
    Ok(b) -> builder_to_string(b)
    Error(err) -> Error(err)
  }
}

pub fn encode_to_builder(
  value: Value,
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  builder.build(value, encode_options)
}

fn builder_to_string(
  builder: bb.BytesBuilder,
) -> Result(String, error.EncodeError) {
  let bits = bb.to_bit_array(builder)
  case bit_array.to_string(bits) {
    Ok(string) -> Ok(string)
    Error(_) ->
      Error(error.encode_error(
        error.OtherEncode("invalid utf8"),
        "encoder produced invalid UTF-8 output",
      ))
  }
}

fn prepare_bits(bits: BitArray) -> Result(String, error.DecodeError) {
  case decode_utf8(bits, 0, []) {
    Ok(codepoints) -> {
      let trimmed = case codepoints {
        [0xFEFF, ..rest] -> rest
        other -> other
      }

      case ints_to_string(trimmed) {
        Ok(text) -> Ok(text)
        Error(_) -> invalid_utf8_error(0)
      }
    }

    Error(position) -> invalid_utf8_error(position)
  }
}

fn remove_bom(text: String) -> String {
  case string.starts_with(text, "\u{FEFF}") {
    True -> string.drop_left(text, 1)
    False -> text
  }
}

fn ints_to_string(ints: List(Int)) -> Result(String, Nil) {
  ints
  |> list.try_fold([], fn(acc, cp) {
    case string.utf_codepoint(cp) {
      Ok(codepoint) -> Ok([codepoint, ..acc])
      Error(_) -> Error(Nil)
    }
  })
  |> result.map(list.reverse)
  |> result.map(string.from_utf_codepoints)
}

fn decode_utf8(
  bits: BitArray,
  index: Int,
  acc: List(Int),
) -> Result(List(Int), Int) {
  case bits {
    <<>> -> Ok(list.reverse(acc))

    <<byte:8, rest:bytes>> ->
      case byte {
        cp if cp <= 0x7F -> decode_utf8(rest, index + 1, [cp, ..acc])

        cp if cp >= 0xC2 && cp <= 0xDF ->
          case rest {
            <<b2:8, tail:bytes>> ->
              case is_continuation(b2) {
                True -> {
                  let value =
                    int.bitwise_or(
                      int.bitwise_shift_left(int.bitwise_and(cp, 0x1F), 6),
                      int.bitwise_and(b2, 0x3F),
                    )
                  decode_utf8(tail, index + 2, [value, ..acc])
                }

                False -> Error(index + 1)
              }

            _ -> Error(index + 1)
          }

        cp if cp >= 0xE0 && cp <= 0xEF ->
          decode_three_byte(cp, rest, index, acc)
        cp if cp >= 0xF0 && cp <= 0xF4 -> decode_four_byte(cp, rest, index, acc)
        _ -> Error(index)
      }

    _ -> Error(index)
  }
}

fn decode_three_byte(
  first: Int,
  rest: BitArray,
  index: Int,
  acc: List(Int),
) -> Result(List(Int), Int) {
  case rest {
    <<b2:8, b3:8, tail:bytes>> -> {
      let valid_second = case first {
        0xE0 -> b2 >= 0xA0 && b2 <= 0xBF
        0xED -> b2 >= 0x80 && b2 <= 0x9F
        _ -> b2 >= 0x80 && b2 <= 0xBF
      }

      case valid_second && is_continuation(b3) {
        True -> {
          let value =
            int.bitwise_or(
              int.bitwise_shift_left(int.bitwise_and(first, 0x0F), 12),
              int.bitwise_or(
                int.bitwise_shift_left(int.bitwise_and(b2, 0x3F), 6),
                int.bitwise_and(b3, 0x3F),
              ),
            )

          case value >= 0xD800 && value <= 0xDFFF {
            True -> Error(index)
            False -> decode_utf8(tail, index + 3, [value, ..acc])
          }
        }

        False -> Error(index + 1)
      }
    }

    _ -> Error(index + 1)
  }
}

fn decode_four_byte(
  first: Int,
  rest: BitArray,
  index: Int,
  acc: List(Int),
) -> Result(List(Int), Int) {
  case rest {
    <<b2:8, b3:8, b4:8, tail:bytes>> -> {
      let valid_second = case first {
        0xF0 -> b2 >= 0x90 && b2 <= 0xBF
        0xF4 -> b2 >= 0x80 && b2 <= 0x8F
        _ -> b2 >= 0x80 && b2 <= 0xBF
      }

      case valid_second && is_continuation(b3) && is_continuation(b4) {
        True -> {
          let value =
            int.bitwise_or(
              int.bitwise_shift_left(int.bitwise_and(first, 0x07), 18),
              int.bitwise_or(
                int.bitwise_shift_left(int.bitwise_and(b2, 0x3F), 12),
                int.bitwise_or(
                  int.bitwise_shift_left(int.bitwise_and(b3, 0x3F), 6),
                  int.bitwise_and(b4, 0x3F),
                ),
              ),
            )

          case value > 0x10FFFF {
            True -> Error(index)
            False -> decode_utf8(tail, index + 4, [value, ..acc])
          }
        }

        False -> Error(index + 1)
      }
    }

    _ -> Error(index + 1)
  }
}

fn is_continuation(byte: Int) -> Bool {
  byte >= 0x80 && byte <= 0xBF
}

fn invalid_utf8_error(position: Int) -> Result(String, error.DecodeError) {
  Error(error.decode_error(
    error.DecodeNotImplemented,
    "input data was not valid UTF-8",
    position,
    option.None,
  ))
}
