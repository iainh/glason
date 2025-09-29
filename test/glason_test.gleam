import gleeunit
import gleeunit/should
import glason/decoder/tokenizer
import glason/value.{Null, Bool}

pub fn main() {
  gleeunit.main()
}

pub fn tokenize_null_literal_test() {
  let input = "null"
  let expected = Ok([tokenizer.TokenValue(Null)])

  tokenizer.tokenize(input)
  |> should.equal(expected)
}

pub fn tokenize_true_literal_test() {
  let input = "true"
  let expected = Ok([tokenizer.TokenValue(Bool(True))])
  tokenizer.tokenize(input)
  |> should.equal(expected)
}
