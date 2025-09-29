import glason/encoder/escape
import glason/error
import glason/fragment
import glason/options
import glason/value
import gleam/bytes_builder as bb
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub fn encode_value(
  value: value.Value,
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  case value {
    value.Null -> Ok(bb.from_string("null"))
    value.Bool(True) -> Ok(bb.from_string("true"))
    value.Bool(False) -> Ok(bb.from_string("false"))
    value.String(text) -> encode_string(text, encode_options)
    value.Int(number) -> Ok(bb.from_string(int.to_string(number)))
    value.Float(number) -> Ok(bb.from_string(float.to_string(number)))
    value.Decimal(number) -> encode_decimal(number)
    value.Array(items) -> encode_array(items, encode_options)
    value.Object(pairs) -> encode_object(pairs, encode_options)
    value.Ordered(obj) ->
      encode_object(value.ordered_object_to_list(obj), encode_options)
    value.Fragment(frag) -> encode_fragment(frag, encode_options)
  }
}

pub fn encode_string(
  value: String,
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  let options.EncodeOptions(escape_mode, _, _) = encode_options
  let escaped = escape.escape_string(value, escape_mode)
  Ok(
    bb.concat([
      bb.from_string("\""),
      bb.from_string(escaped),
      bb.from_string("\""),
    ]),
  )
}

fn encode_array(
  values: List(value.Value),
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  case values {
    [] -> Ok(bb.from_string("[]"))
    [first, ..rest] ->
      encode_value(first, encode_options)
      |> result.try(fn(first_builder) {
        encode_array_tail(
          rest,
          encode_options,
          bb.concat([
            bb.from_string("["),
            first_builder,
          ]),
        )
      })
  }
}

fn encode_array_tail(
  values: List(value.Value),
  encode_options: options.EncodeOptions,
  acc: bb.BytesBuilder,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  case values {
    [] -> Ok(bb.append_string(acc, "]"))
    [head, ..tail] ->
      encode_value(head, encode_options)
      |> result.try(fn(builder) {
        let next =
          bb.concat([
            acc,
            bb.from_string(","),
            builder,
          ])
        encode_array_tail(tail, encode_options, next)
      })
  }
}

fn encode_object(
  pairs: List(#(String, value.Value)),
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  let options.EncodeOptions(_, map_mode, _) = encode_options
  case map_mode {
    options.MapsStrict ->
      case detect_duplicate_key(pairs) {
        Some(key) ->
          Error(error.encode_error(
            error.DuplicateKey(key),
            "duplicate key: " <> key,
          ))
        None -> encode_object_pairs(pairs, encode_options)
      }

    options.MapsNaive -> encode_object_pairs(pairs, encode_options)
  }
}

fn encode_object_pairs(
  pairs: List(#(String, value.Value)),
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  case pairs {
    [] -> Ok(bb.from_string("{}"))
    [first, ..rest] ->
      encode_object_pair(first, encode_options)
      |> result.try(fn(first_builder) {
        encode_object_tail(
          rest,
          encode_options,
          bb.concat([
            bb.from_string("{"),
            first_builder,
          ]),
        )
      })
  }
}

fn encode_object_tail(
  pairs: List(#(String, value.Value)),
  encode_options: options.EncodeOptions,
  acc: bb.BytesBuilder,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  case pairs {
    [] -> Ok(bb.append_string(acc, "}"))
    [head, ..tail] ->
      encode_object_pair(head, encode_options)
      |> result.try(fn(builder) {
        let next =
          bb.concat([
            acc,
            bb.from_string(","),
            builder,
          ])
        encode_object_tail(tail, encode_options, next)
      })
  }
}

fn encode_object_pair(
  pair: #(String, value.Value),
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  let #(key, value) = pair
  encode_string(key, encode_options)
  |> result.try(fn(key_builder) {
    encode_value(value, encode_options)
    |> result.map(fn(value_builder) {
      bb.concat([
        key_builder,
        bb.from_string(":"),
        value_builder,
      ])
    })
  })
}

fn encode_decimal(
  number: value.DecimalNumber,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  Ok(bb.from_string(value.decimal_to_string(number)))
}

fn encode_fragment(
  fragment_value: fragment.Fragment,
  encode_options: options.EncodeOptions,
) -> Result(bb.BytesBuilder, error.EncodeError) {
  fragment.to_builder(fragment_value, encode_options)
}

fn detect_duplicate_key(pairs: List(#(String, value.Value))) -> Option(String) {
  detect_duplicate_key_loop(pairs, [])
}

fn detect_duplicate_key_loop(
  pairs: List(#(String, value.Value)),
  seen: List(String),
) -> Option(String) {
  case pairs {
    [] -> None
    [#(key, _value), ..rest] ->
      case list.contains(seen, key) {
        True -> Some(key)
        False -> detect_duplicate_key_loop(rest, [key, ..seen])
      }
  }
}
