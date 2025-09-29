import gleeunit
import gleeunit/should
import glason
import glason/decoder/tokenizer
import glason/options
import glason/value
import gleam/string

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
  let expected = Ok([
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
  |> should.equal(Ok(value.Array([value.Bool(True), value.Null, value.String("hi")])) )
}

pub fn decode_simple_object_test() {
  glason.decode("{\"a\": 1, \"b\": \"hi\"}")
  |> should.equal(Ok(value.Object([
    #("a", value.Int(1)),
    #("b", value.String("hi")),
  ])))
}

pub fn decode_float_value_test() {
  glason.decode("3.14")
  |> should.equal(Ok(value.Float(3.14)))
}

pub fn decode_exponent_value_test() {
  glason.decode("1e2")
  |> should.equal(Ok(value.Float(100.0)))
}

pub fn decode_invalid_leading_zero_test() {
  glason.decode("01")
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

pub fn decode_decimals_option_error_test() {
  let decode_opts =
    options.default_decode_options()
    |> options.set_float_mode(options.FloatsDecimals)

  glason.decode_with("1.0", decode_opts)
  |> should.be_error()
}
