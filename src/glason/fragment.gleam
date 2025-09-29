import glason/error
import glason/options
import gleam/bytes_builder as bb

pub type Fragment {
  Fragment(
    fn(options.EncodeOptions) -> Result(bb.BytesBuilder, error.EncodeError),
  )
}

pub fn new(
  encode: fn(options.EncodeOptions) ->
    Result(bb.BytesBuilder, error.EncodeError),
) -> Fragment {
  Fragment(encode)
}

pub fn from_string(json: String) -> Fragment {
  new(fn(_options) { Ok(bb.from_string(json)) })
}

pub fn to_builder(
  fragment: Fragment,
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  let Fragment(encode) = fragment
  encode(encode_options)
}
