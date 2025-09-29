# Glason

Glason is a work-in-progress Gleam port of the [Jason](https://github.com/michalmuskala/jason) JSON library.

## Status

- Decoder covers literals, numbers (native floats or decimal strings), arrays, objects, and the configurable option surface. Inputs may be UTF-8 strings, binaries (`BitArray`), or iodata; UTF-8 BOMs are stripped automatically.
- Encoder supports the same `Value` variants (including ordered objects and decimals); formatter and helper APIs are still pending.

## Deviations from Jason

- Atom key modes (`KeysAtoms`, `KeysExistingAtoms`) are currently **not supported**. Gleam’s backend-neutral story for atoms is still evolving, so for now all decoded keys remain strings. The option setters are present but will return an error if used.
- String copy/reference modes, duplicate key checks, and ordered objects work for maps, but deeper BEAM-specific optimisations (like referencing original binaries) are deferred.
- Decimal float mode produces `Value.Decimal` values that wrap the original JSON lexeme instead of an arbitrary precision math type (keeping the implementation backend-neutral).
- Encoder escape modes (`EscapeJavascriptSafe`, `EscapeHtmlSafe`, `EscapeUnicodeSafe`) mirror Jason's behaviour for escaping problematic characters and can be composed with custom encoders.

## Development

Run the test suite with:

```sh
gleam test
```

Tests currently emit warnings due to placeholder encoder usage of deprecated APIs—this will be resolved once the encoder is implemented.

## Fragments & Custom Encoders

- `glason/fragment` lets you cache or embed pre-rendered JSON chunks inside larger structures without re-encoding them.
- `glason/encode` provides a small combinator library for describing encoders for your own Gleam types. Encoders compose (lists, options, nested objects) and reuse the same `EncodeOptions` used by the core API.

```gleam
import glason/encode
import glason/fragment
import glason/value

pub type Profile {
  Profile(name: String, tags: List(String))
}

pub fn profile_encoder() -> encode.Encoder(Profile) {
  encode.object([
    encode.field("name", encode.string(), fn(Profile(name, _)) { name }),
    encode.field("tags", encode.list(encode.string()), fn(Profile(_, tags)) { tags }),
  ])
}

pub fn to_json(profile: Profile) {
  encode.encode(profile, profile_encoder())
}

pub fn from_fragment(json: String) {
  value.fragment(fragment.from_string(json))
}
```

## Goals

- Achieve feature parity with Jason where possible in pure Gleam.
- Provide a backend-neutral API usable on the BEAM and future Gleam targets.
- Maintain strong tests and documentation as features land.

Contributions and feedback are welcome!
