import gleam/bit_builder
import glason/error
import glason/options
import glason/value.{type Value}
import glason/encoder/writer

pub fn build(value: Value, encode_options: options.EncodeOptions) -> Result(bit_builder.BitBuilder, error.EncodeError) {
  writer.encode_value(value, encode_options)
}
