import gleam/bytes_builder as bb
import gleam/bit_array
import glason/error
import glason/options
import glason/value.{type Value}
import glason/decoder/parser
import glason/encoder/builder

pub fn decode(input: String) -> Result(Value, error.DecodeError) {
  decode_with(input, options.default_decode_options())
}

pub fn decode_with(input: String, decode_options: options.DecodeOptions) -> Result(Value, error.DecodeError) {
  parser.parse_binary(input, decode_options)
}

pub fn encode(value: Value) -> Result(String, error.EncodeError) {
  encode_with(value, options.default_encode_options())
}

pub fn encode_with(value: Value, encode_options: options.EncodeOptions) -> Result(String, error.EncodeError) {
  case builder.build(value, encode_options) {
    Ok(b) -> builder_to_string(b)
    Error(err) -> Error(err)
  }
}

pub fn encode_to_builder(value: Value, encode_options: options.EncodeOptions) -> Result(bb.BytesBuilder, error.EncodeError) {
  builder.build(value, encode_options)
}

fn builder_to_string(builder: bb.BytesBuilder) -> Result(String, error.EncodeError) {
  let bits = bb.to_bit_array(builder)
  case bit_array.to_string(bits) {
    Ok(string) -> Ok(string)
    Error(_) ->
      Error(
        error.encode_error(
          error.OtherEncode("invalid utf8"),
          "encoder produced invalid UTF-8 output",
        ),
      )
  }
}
