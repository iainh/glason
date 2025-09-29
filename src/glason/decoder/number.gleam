import glason/error
import glason/options

pub fn parse_float(
  bytes: String,
  decode_options: options.DecodeOptions,
) -> Result(Float, error.DecodeError) {
  let _ = bytes
  let _ = decode_options
  Error(error.not_implemented_decode_error())
}

pub fn parse_integer(bytes: String) -> Result(Int, error.DecodeError) {
  let _ = bytes
  Error(error.not_implemented_decode_error())
}
