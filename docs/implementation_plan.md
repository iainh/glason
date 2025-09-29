# Glason Implementation Plan

## 1. Background & Goals
- Port the [`Jason`](https://github.com/michalmuskala/jason) Elixir library to Gleam with feature parity where practical.
- Deliver a Gleam-first API while staying interoperable with Erlang data and IO.
- Preserve Jason's performance focus (binary pattern matching, minimal allocations) and broad test coverage.

## 2. Source Library Audit
Modules and their primary responsibilities in Jason:
- `Jason` – public API: `encode/2`, `decode/2`, options normalization.
- `Jason.Decoder` & `Jason.DecodeError` – binary parser, stack machine, decode error struct.
- `Jason.Encode` & `Jason.EncodeError` – encoding primitives, escape handling, map options.
- `Jason.Encoder` protocol – derivation helpers for structs (macro/protocol heavy).
- `Jason.Formatter` – pretty-printing and minifying utilities.
- `Jason.OrderedObject` – ordered map wrapper with Access implementation.
- `Jason.Helpers`, `Jason.Fragment`, `Jason.Codegen`, `Jason.Sigil` – compile-time helpers, macros, sigils, and code generation support.
- Tests reside under `test/` with property-style coverage; JSON fixtures live in `json_test_suite/` and formatter suite.

## 3. Target Gleam Package Layout
```
src/
  glason.gleam                 # public API: encode/decode, option builders
  glason/options.gleam         # option records and validation helpers
  glason/value.gleam           # JSON value enum, ordered object abstraction
  glason/error.gleam           # DecodeError, EncodeError types
  glason/decoder/
    tokenizer.gleam            # UTF-8 aware scanning/token stream
    number.gleam               # number parsing helpers
    parser.gleam               # state machine turning tokens into values
  glason/encoder/
    escape.gleam               # escape strategies
    writer.gleam               # encode primitives (lists, maps, strings)
    builder.gleam              # high-level encode entry points
  glason/formatter.gleam       # pretty/minified rendering functions
  glason/fragment.gleam        # cached iodata fragments
  glason/internal/codegen.gleam# specialised tables (generated from scripts)
  glason/internal/util.gleam   # shared helpers (bit ops, stack utils)

test/
  decoder_test.gleam
  encoder_test.gleam
  formatter_test.gleam
  integration_test.gleam
  property/                     # property tests (gleam_erlang + stream data)
```
- Keep internal modules namespaced to discourage external use.
- Expose a minimal public surface mirroring Jason's ergonomics (`decode`, `decode_with`, `encode`, `encode_to` etc.).

## 4. Core Data Structures
- `pub type Value` mirroring JSON primitives plus `Value(Object(List(tuple(String, Value))))` and `Value(Array(List(Value)))`.
- `pub type OrderedObject` retaining insertion order; implemented as `List(tuple(String, Value))` with helper functions (`get`, `pop`).
- `pub type DecodeError` with fields `(position: Int, token: Option(String), data: BitString)`, using `Result(Value, DecodeError)` in API.
- `pub type EncodeError` capturing duplicate keys / invalid bytes.
- `pub type Options` record bundling encode/decode flags:
  - Decode: `keys`, `strings`, `floats`, `objects`.
  - Encode: `escape`, `maps`, `pretty`.
  - Provide constructors (`default_options`, `set_keys`, …) returning `Options` for ergonomic updates.

## 5. Decoding Strategy
- Implement tokenizer using binary pattern matching (`bit_string` segments) replicating Jason's jump table logic; convert macros to generated Gleam pattern clauses (codegen helper).
- Parser operates as explicit tail-recursive state machine with a manual stack (`List(State)`) to match Jason's performance characteristics.
- Float parsing: wrap `gleam_erlang` interop to call `erlang:binary_to_float/1`; decimals option delegates to optional `decimal` Erlang library (guard with compile-time flag / feature).
- Keys/string strategies: functions stored in options record, applied post-tokenization to avoid allocations.
- Objects: return either Gleam `Map` or `OrderedObject` depending on option selection.

## 6. Encoding Strategy
- Provide `fn encode(value: Value, options) -> Result(BitString, EncodeError)` plus convenience `encode_from(a, encoder)` for custom types.
- Replace protocol-based dispatch with two layers:
  1. Built-in clause coverage via pattern matching for Gleam/Erlang primitives.
  2. `type Encoder(a) = fn(a) -> ValueBuilder` to let users register custom encoders; supply combinators similar to `Jason.Helpers`.
- Mirror escape modes (`json`, `html_safe`, `javascript_safe`, `unicode_safe`). `escape.gleam` encapsulates per-mode logic using bitstring builders.
- Map handling: `:strict` mode performs duplicate key detection via map of seen string keys.
- Provide fragment support by accepting `Fragment` type wrapping an `fn(opts) -> BitBuilder`.

## 7. Formatter & Helpers
- Port formatter as streaming transformation over input `BitStringBuilder`; share indentation utilities with encoder.
- Implement `Fragment` as a wrapper around `fn(escape, map_encoder) -> IoData` to preserve lazy composition.
- `helpers` macros become regular functions returning fragments; no compile-time macros in Gleam, so we expose runtime builders and optionally generate specialisations via `codegen` module for common key sets.
- Sigils have no Gleam equivalent; document omission and provide helper functions for embedding JSON literals at compile time using build scripts if needed.

## 8. Interop & Performance Considerations
- Lean on `gleam_erlang` for bitstring slicing, `binary:at/2`, and map/list translations.
- Evaluate generating jump tables using an offline script (Gleam build script) to keep decoder fast without macros.
- Ensure tail-call optimisation via recursion; avoid anonymous function allocation in hot paths.
- Provide `glason/stream` module later if streaming encode/decode required (phase 2), using Gleam `Iterator` or Erlang messages.

## 9. Testing & Tooling
- Port Jason's fixtures into `test/fixtures/`; reuse JSON corpus for parity testing.
- Add cross-language validation: optional test calling into the original Jason (if available) comparing outputs.
- Property tests (optional) using `gleam_erlang/prop_test` to fuzz decode/encode round-trips.
- Integrate `gleam test` in CI; add bench scripts (Erlang escripts) to compare throughput.
- Formatting via `gleam format`; document required dependencies.

## 10. Milestones
1. **Project bootstrap** – Initial Gleam package, options types, scaffolding for encoder/decoder modules, CI setup.
2. **Decoder core** – Tokenizer + parser delivering `Result(Value, DecodeError)`; pass basic JSON test suite.
3. **Encoder core** – Value encoder with escape modes and map handling; support fragments and ordered objects.
4. **Advanced features** – Formatter, pretty printing, strict map checks, decimal floats, optional native escape interop.
5. **Helpers & ergonomics** – Runtime fragments, user encoder registration API, documentation with examples.
6. **Parity validation** – Port Jason tests, integrate fixtures, add property tests; run benchmarks and compare with Elixir Jason.
7. **Release prep** – README, migration notes, packaging metadata, publishable Gleam hex package.

Each milestone concludes with documentation updates and targeted benchmarking, ensuring regressions are caught early.
