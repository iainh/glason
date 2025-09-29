import gleam/bit_builder
import glason/error
import glason/options
import glason/value.{type Value}
import glason/encoder/escape

pub fn encode_value(value: Value, encode_options: options.EncodeOptions) -> Result(bit_builder.BitBuilder, error.EncodeError) {
  let _ = value
  let _ = encode_options
  Error(error.not_implemented_encode_error())
}

pub fn encode_string(value: String, encode_options: options.EncodeOptions) -> Result(bit_builder.BitBuilder, error.EncodeError) {
  let options.EncodeOptions(escape_mode, _, _) = encode_options
  let builder = escape.escape_string(value, escape_mode)
  Ok(builder)
}
