import glason/encoder/writer
import glason/error
import glason/options
import glason/value.{type Value}
import gleam/bytes_builder.{type BytesBuilder}

pub fn build(
  value: Value,
  encode_options: options.EncodeOptions,
) -> Result(BytesBuilder, error.EncodeError) {
  writer.encode_value(value, encode_options)
}
