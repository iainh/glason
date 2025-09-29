# Glason

Glason is a work-in-progress Gleam port of the [Jason](https://github.com/michalmuskala/jason) JSON library.

## Status

- Decoder support for strings, numbers, arrays, objects, and options is being built out incrementally.
- Encoder, formatter, and helper APIs are not yet implemented.

## Deviations from Jason

- Atom key modes (`KeysAtoms`, `KeysExistingAtoms`) are currently **not supported**. Gleam’s backend-neutral story for atoms is still evolving, so for now all decoded keys remain strings. The option setters are present but will return an error if used.
- String copy/reference modes, duplicate key checks, and ordered objects work for maps, but deeper BEAM-specific optimisations (like referencing original binaries) are deferred.
- Encoder escape modes (`EscapeJavascriptSafe`, `EscapeHtmlSafe`, `EscapeUnicodeSafe`) currently behave the same as plain JSON escaping. Additional escaping behaviour will be implemented in future passes.

## Development

Run the test suite with:

```sh
gleam test
```

Tests currently emit warnings due to placeholder encoder usage of deprecated APIs—this will be resolved once the encoder is implemented.

## Goals

- Achieve feature parity with Jason where possible in pure Gleam.
- Provide a backend-neutral API usable on the BEAM and future Gleam targets.
- Maintain strong tests and documentation as features land.

Contributions and feedback are welcome!
