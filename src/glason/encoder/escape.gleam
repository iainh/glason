import gleam/bit_builder
import glason/options

pub fn escape_string(input: String, mode: options.EscapeMode) -> bit_builder.BitBuilder {
  let _ = input
  let _ = mode
  bit_builder.new()
}
