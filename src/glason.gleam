import glason/decoder/parser
import glason/encoder/builder
import glason/error
import glason/options
import glason/value.{type Value}
import gleam/bit_array
import gleam/bytes_builder as bb
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
  case bit_array.to_string(bits) {
    Ok(text) -> Ok(remove_bom(text))
    Error(_) ->
      Error(error.decode_error(
        error.DecodeNotImplemented,
        "input data was not valid UTF-8",
        0,
        option.None,
      ))
  }
}

fn remove_bom(text: String) -> String {
  case string.starts_with(text, "\u{FEFF}") {
    True -> string.drop_left(text, 1)
    False -> text
  }
}
