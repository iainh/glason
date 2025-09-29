import glason
import glason/decoder/tokenizer
import glason/encode
import glason/error
import glason/fragment
import glason/options
import glason/value
import gleam/bit_array
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn tokenize_null_literal_test() {
  let input = "null"
  let expected = Ok([tokenizer.TokenValue(value.Null)])

  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_true_literal_test() {
  let input = "true"
  let expected = Ok([tokenizer.TokenValue(value.Bool(True))])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_string_literal_test() {
  let input = "\"hello\""
  let expected = Ok([tokenizer.TokenString("hello")])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_integer_literal_test() {
  let input = "-123"
  let expected = Ok([tokenizer.TokenNumber("-123")])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_escape_sequences_test() {
  let input = "\"\\\\\""
  let expected = Ok([tokenizer.TokenString("\\")])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_float_literal_test() {
  let input = "12.34e-2"
  let expected = Ok([tokenizer.TokenNumber("12.34e-2")])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_unicode_escape_test() {
  let input = "\"\\u0041\""
  let expected = Ok([tokenizer.TokenString("A")])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_object_tokens_test() {
  let input = "{\"a\":1}"
  let expected =
    Ok([
      tokenizer.TokenStartObject,
      tokenizer.TokenString("a"),
      tokenizer.TokenColon,
      tokenizer.TokenNumber("1"),
      tokenizer.TokenEndObject,
    ])

  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn decode_true_value_test() {
  glason.decode("true")
  |> should.equal(Ok(value.Bool(True)))
}

pub fn decode_string_value_test() {
  glason.decode("\"hi\"")
  |> should.equal(Ok(value.String("hi")))
}

pub fn decode_number_value_test() {
  glason.decode("42")
  |> should.equal(Ok(value.Int(42)))
}

pub fn decode_escaped_string_test() {
  glason.decode("\"line\\n\"")
  |> should.equal(Ok(value.String("line\n")))
}

pub fn decode_simple_array_test() {
  glason.decode("[true, null, \"hi\"]")
  |> should.equal(
    Ok(value.Array([value.Bool(True), value.Null, value.String("hi")])),
  )
}

pub fn decode_array_of_objects_test() {
  glason.decode("[{\"foo\":\"bar\"},{\"baz\":\"quux\"}]")
  |> should.equal(
    Ok(
      value.Array([
        value.Object([#("foo", value.String("bar"))]),
        value.Object([#("baz", value.String("quux"))]),
      ]),
    ),
  )
}

pub fn decode_simple_object_test() {
  glason.decode("{\"a\": 1, \"b\": \"hi\"}")
  |> should.equal(
    Ok(
      value.Object([
        #("a", value.Int(1)),
        #("b", value.String("hi")),
      ]),
    ),
  )
}

pub fn decode_nested_object_test() {
  glason.decode("{\"foo\": {\"bar\": \"baz\"}}")
  |> should.equal(
    Ok(
      value.Object([
        #("foo", value.Object([#("bar", value.String("baz"))])),
      ]),
    ),
  )
}

pub fn decode_ordered_object_option_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_object_mode(options.ObjectsOrdered)

  glason.decode_with("{\"a\":1,\"b\":2}", decode_opts)
  |> should.equal(
    Ok(
      value.Ordered(
        value.ordered_object([
          #("a", value.Int(1)),
          #("b", value.Int(2)),
        ]),
      ),
    ),
  )
}

pub fn decode_float_value_test() {
  glason.decode("3.14")
  |> should.equal(Ok(value.Float(3.14)))
}

pub fn decode_exponent_value_test() {
  glason.decode("1e2")
  |> should.equal(Ok(value.Float(100.0)))
}

pub fn decode_unicode_escape_sequences_test() {
  glason.decode("\"\\u2603\"")
  |> should.equal(Ok(value.String("☃")))

  glason.decode("\"\\uD834\\uDD1E\"")
  |> should.equal(Ok(value.String("𝄞")))

  glason.decode("\"\\uDD1E\"")
  |> should.be_error()
}

pub fn decode_surrogate_pair_arrays_test() {
  glason.decode("[\"\\uD801\\uDC37\"]")
  |> should.equal(Ok(value.Array([value.String("\u{10437}")])))

  glason.decode("[\"\\uD83D\\uDE39\\uD83D\\uDC8D\"]")
  |> should.equal(Ok(value.Array([value.String("\u{1F639}\u{1F48D}")])))

  glason.decode("[\"\\uDBFF\\uDFFF\"]")
  |> should.equal(Ok(value.Array([value.String("\u{10FFFF}")])))

  glason.decode("[\"\\uD834\\uDd1e\"]")
  |> should.equal(Ok(value.Array([value.String("\u{1D11E}")])))
}

pub fn decode_surrogate_error_cases_test() {
  glason.decode("[\"\\uD800\\u\"]")
  |> should.be_error()

  glason.decode("[\"\\uD834\\uDd\"]")
  |> should.be_error()

  glason.decode("[\"\\uDD00\"]")
  |> should.be_error()
}

pub fn decode_unicode_noncharacter_codepoints_test() {
  assert_codepoints("[\"\\uFDD0\"]", [0xFDD0])
  assert_codepoints("[\"\\uFFFE\"]", [0xFFFE])
  assert_codepoints("[\"\\uDBFF\\uDFFE\"]", [0x10FFFE])
  assert_codepoints("[\"\\uD83F\\uDFFE\"]", [0x1FFFE])
}

pub fn decode_additional_unicode_escape_fixtures_test() {
  assert_codepoints("[\"\\u0000\"]", [0x0])
  assert_codepoints("[\"\\u005C\"]", [0x5C])
  assert_codepoints("[\"\\uFFFF\"]", [0xFFFF])
}

pub fn decode_binary_with_bom_test() {
  let bom = bit_array.from_string("\u{FEFF}")
  let payload = bit_array.from_string("{\"a\":1}")
  let input = bit_array.concat([bom, payload])

  glason.decode_binary(input)
  |> should.equal(Ok(value.Object([#("a", value.Int(1))])))
}

pub fn decode_iodata_segments_test() {
  let segments = [
    bit_array.from_string("{"),
    bit_array.from_string("\"a\""),
    bit_array.from_string(":"),
    bit_array.from_string("true"),
    bit_array.from_string("}"),
  ]

  glason.decode_iodata(segments)
  |> should.equal(Ok(value.Object([#("a", value.Bool(True))])))
}

pub fn decode_invalid_utf8_position_test() {
  let invalid_start: BitArray = <<0xFF:8>>

  glason.decode_binary(invalid_start)
  |> should.equal(
    Error(error.decode_error(
      error.DecodeNotImplemented,
      "input data was not valid UTF-8",
      0,
      option.None,
    )),
  )

  let invalid_sequence: BitArray = <<0xE2:8, 0x28:8, 0xA1:8>>

  glason.decode_binary(invalid_sequence)
  |> should.equal(
    Error(error.decode_error(
      error.DecodeNotImplemented,
      "input data was not valid UTF-8",
      1,
      option.None,
    )),
  )
}

pub fn decode_invalid_leading_zero_test() {
  glason.decode("01")
  |> should.be_error()
}

pub fn decode_trailing_comma_error_test() {
  glason.decode("[1,]")
  |> should.be_error()
}

pub fn decode_atoms_option_error_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_key_mode(options.KeysAtoms)

  glason.decode_with("{\"a\":1}", decode_opts)
  |> should.be_error()
}

pub fn decode_custom_key_transform_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_key_mode(options.KeysCustom(string.uppercase))

  glason.decode_with("{\"a\":1}", decode_opts)
  |> should.equal(Ok(value.Object([#("A", value.Int(1))])))
}

pub fn decode_decimals_option_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_float_mode(options.FloatsDecimals)

  glason.decode_with("1.0", decode_opts)
  |> should.equal(Ok(value.Decimal(value.decimal("1.0"))))
}

pub fn decode_decimals_large_number_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_float_mode(options.FloatsDecimals)

  glason.decode_with("123456789012345678901234567890.123", decode_opts)
  |> should.equal(
    Ok(value.Decimal(value.decimal("123456789012345678901234567890.123"))),
  )
}

pub fn decode_whitespace_tolerance_test() {
  glason.decode("  {  \"a\"  :  [ 1 , 2 ] }  ")
  |> should.equal(
    Ok(
      value.Object([
        #(
          "a",
          value.Array([
            value.Int(1),
            value.Int(2),
          ]),
        ),
      ]),
    ),
  )
}

pub fn decode_strict_map_duplicate_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_decode_map_mode(options.MapsStrict)

  glason.decode_with("{\"a\":1,\"a\":2}", decode_opts)
  |> should.be_error()
}

pub fn decode_string_copy_mode_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_string_mode(options.StringsCopy)

  glason.decode_with("\"copy\"", decode_opts)
  |> should.equal(Ok(value.String("copy")))
}

pub fn encode_string_value_test() {
  glason.encode(value.String("hi\""))
  |> should.equal(Ok("\"hi\\\"\""))
}

pub fn encode_array_value_test() {
  glason.encode(value.Array([value.Int(1), value.Bool(False)]))
  |> should.equal(Ok("[1,false]"))
}

pub fn encode_object_value_test() {
  glason.encode(value.Object([#("a", value.Int(1)), #("b", value.Bool(True))]))
  |> should.equal(Ok("{\"a\":1,\"b\":true}"))
}

pub fn encode_javascript_safe_escape_test() {
  let encode_opts =
    options.default_encode_options()
    |> options.set_escape_mode(options.EscapeJavascriptSafe)

  glason.encode_with(value.String("line\u{2028}sep\u{2029}"), encode_opts)
  |> should.equal(Ok("\"line\\u2028sep\\u2029\""))
}

pub fn encode_html_safe_escape_test() {
  let encode_opts =
    options.default_encode_options()
    |> options.set_escape_mode(options.EscapeHtmlSafe)

  glason.encode_with(value.String("</script>\u{2028}"), encode_opts)
  |> should.equal(Ok("\"\\u003C\\/script>\\u2028\""))
}

pub fn encode_unicode_safe_escape_test() {
  let encode_opts =
    options.default_encode_options()
    |> options.set_escape_mode(options.EscapeUnicodeSafe)

  glason.encode_with(value.String("€"), encode_opts)
  |> should.equal(Ok("\"\\u20AC\""))
}

pub fn encode_unicode_safe_surrogate_test() {
  let encode_opts =
    options.default_encode_options()
    |> options.set_escape_mode(options.EscapeUnicodeSafe)

  glason.encode_with(value.String("𝄞"), encode_opts)
  |> should.equal(Ok("\"\\uD834\\uDD1E\""))
}

pub fn encode_fragment_array_test() {
  let frag = fragment.from_string("{\"cached\":true}")
  glason.encode(value.Array([value.Fragment(frag)]))
  |> should.equal(Ok("[{\"cached\":true}]"))
}

type Tag {
  Tag(name: String)
}

type Profile {
  Profile(
    name: String,
    tags: List(Tag),
    cached: fragment.Fragment,
    bio: option.Option(String),
  )
}

pub fn encode_nested_custom_type_test() {
  let tag_encoder =
    encode.object([
      encode.field("name", encode.string(), fn(tag) {
        let Tag(name) = tag
        name
      }),
    ])

  let profile_encoder =
    encode.object([
      encode.field("name", encode.string(), fn(profile) {
        let Profile(name, _, _, _) = profile
        name
      }),
      encode.field("tags", encode.list(tag_encoder), fn(profile) {
        let Profile(_, tags, _, _) = profile
        tags
      }),
      encode.field("cached", encode.fragment(), fn(profile) {
        let Profile(_, _, cached, _) = profile
        cached
      }),
      encode.optional_field("bio", encode.string(), fn(profile) {
        let Profile(_, _, _, bio) = profile
        bio
      }),
    ])

  let cached = fragment.from_string("{\"precomputed\":false}")
  let profile = Profile("Ada", [Tag("gleam")], cached, option.None)

  encode.encode(profile, profile_encoder)
  |> should.equal(Ok(
    "{\"name\":\"Ada\",\"tags\":[{\"name\":\"gleam\"}],\"cached\":{\"precomputed\":false}}",
  ))
}

fn assert_codepoints(json: String, expected: List(Int)) {
  decode_codepoints(json)
  |> should.equal(Ok(expected))
}

fn decode_codepoints(json: String) -> Result(List(Int), error.DecodeError) {
  glason.decode(json)
  |> result.then(fn(value) {
    case value {
      value.Array([value.String(text)]) ->
        string.to_utf_codepoints(text)
        |> list.map(string.utf_codepoint_to_int)
        |> Ok

      _ -> Error(error.not_implemented_decode_error())
    }
  })
}
