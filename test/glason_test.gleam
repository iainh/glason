import gleeunit
import gleeunit/should
import glason
import glason/decoder/tokenizer
import glason/value

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
