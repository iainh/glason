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
