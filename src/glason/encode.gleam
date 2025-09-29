import glason
import glason/error
import glason/fragment as json_fragment
import glason/options
import glason/value as json_value
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Encoder(subject) {
  Encoder(
    fn(subject, options.EncodeOptions) ->
      Result(json_value.Value, error.EncodeError),
  )
}

pub type FieldEncoder(subject) =
  fn(subject, options.EncodeOptions) ->
    Result(List(#(String, json_value.Value)), error.EncodeError)

pub fn custom(
  encode: fn(subject, options.EncodeOptions) ->
    Result(json_value.Value, error.EncodeError),
) -> Encoder(subject) {
  Encoder(encode)
}

pub fn contramap(
  encoder: Encoder(inner),
  project: fn(subject) -> inner,
) -> Encoder(subject) {
  let Encoder(run) = encoder
  Encoder(fn(subject, options) { run(project(subject), options) })
}

pub fn transform(
  encoder: Encoder(inner),
  project: fn(subject, options.EncodeOptions) ->
    Result(inner, error.EncodeError),
) -> Encoder(subject) {
  let Encoder(run) = encoder
  Encoder(fn(subject, options) {
    project(subject, options)
    |> result.try(fn(value) { run(value, options) })
  })
}

pub fn value() -> Encoder(json_value.Value) {
  Encoder(fn(value, _options) { Ok(value) })
}

pub fn bool() -> Encoder(Bool) {
  Encoder(fn(value, _options) { Ok(json_value.Bool(value)) })
}

pub fn string() -> Encoder(String) {
  Encoder(fn(value, _options) { Ok(json_value.String(value)) })
}

pub fn int() -> Encoder(Int) {
  Encoder(fn(value, _options) { Ok(json_value.Int(value)) })
}

pub fn float() -> Encoder(Float) {
  Encoder(fn(value, _options) { Ok(json_value.Float(value)) })
}

pub fn decimal() -> Encoder(json_value.DecimalNumber) {
  Encoder(fn(value, _options) { Ok(json_value.Decimal(value)) })
}

pub fn fragment() -> Encoder(json_fragment.Fragment) {
  Encoder(fn(value, _options) { Ok(json_value.Fragment(value)) })
}

pub fn list(element_encoder: Encoder(element)) -> Encoder(List(element)) {
  let Encoder(run_element) = element_encoder
  Encoder(fn(values, options) {
    list.fold(values, Ok([]), fn(acc_result, current) {
      acc_result
      |> result.try(fn(acc) {
        run_element(current, options)
        |> result.map(fn(encoded) { [encoded, ..acc] })
      })
    })
    |> result.map(fn(reversed) { json_value.Array(list.reverse(reversed)) })
  })
}

pub fn option(inner: Encoder(inner)) -> Encoder(Option(inner)) {
  let Encoder(run_inner) = inner
  Encoder(fn(value, options) {
    case value {
      Some(inner_value) -> run_inner(inner_value, options)
      None -> Ok(json_value.Null)
    }
  })
}

pub fn object(fields: List(FieldEncoder(subject))) -> Encoder(subject) {
  Encoder(fn(subject, options) {
    build_pairs(fields, subject, options)
    |> result.map(fn(pairs) { json_value.Object(pairs) })
  })
}

pub fn ordered_object(fields: List(FieldEncoder(subject))) -> Encoder(subject) {
  Encoder(fn(subject, options) {
    build_pairs(fields, subject, options)
    |> result.map(fn(pairs) {
      json_value.Ordered(json_value.ordered_object(pairs))
    })
  })
}

pub fn field(
  name: String,
  encoder: Encoder(field),
  project: fn(subject) -> field,
) -> FieldEncoder(subject) {
  let Encoder(run) = encoder
  fn(subject, options) {
    run(project(subject), options)
    |> result.map(fn(value) { [#(name, value)] })
  }
}

pub fn optional_field(
  name: String,
  encoder: Encoder(field),
  project: fn(subject) -> Option(field),
) -> FieldEncoder(subject) {
  let Encoder(run) = encoder
  fn(subject, options) {
    case project(subject) {
      Some(value) ->
        run(value, options)
        |> result.map(fn(encoded) { [#(name, encoded)] })

      None -> Ok([])
    }
  }
}

pub fn encode(
  subject: subject,
  encoder: Encoder(subject),
) -> Result(String, error.EncodeError) {
  encode_with(subject, encoder, options.default_encode_options())
}

pub fn encode_with(
  subject: subject,
  encoder: Encoder(subject),
  encode_options: options.EncodeOptions,
) -> Result(String, error.EncodeError) {
  to_value(subject, encoder, encode_options)
  |> result.try(fn(value) { glason.encode_with(value, encode_options) })
}

pub fn to_value(
  subject: subject,
  encoder: Encoder(subject),
  encode_options: options.EncodeOptions,
) -> Result(json_value.Value, error.EncodeError) {
  let Encoder(run) = encoder
  run(subject, encode_options)
}

fn build_pairs(
  fields: List(FieldEncoder(subject)),
  subject: subject,
  encode_options: options.EncodeOptions,
) -> Result(List(#(String, json_value.Value)), error.EncodeError) {
  list.fold(fields, Ok([]), fn(acc_result, current_field) {
    acc_result
    |> result.try(fn(acc) {
      current_field(subject, encode_options)
      |> result.map(fn(pairs) { list.concat([acc, pairs]) })
    })
  })
}
