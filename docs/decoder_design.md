# Decoder Design Outline

## Goals
- Provide a pure Gleam decoder that accepts UTF-8 JSON input as `BitString` and returns `Result(Value, DecodeError)`.
- Match Jason's performance characteristics where possible: single pass, minimal allocations, binary pattern matching.
- Support options for keys, strings, floats, and object representation via `options.DecodeOptions`.

## Components
1. **Tokenizer (`glason/decoder/tokenizer`)**
   - Scans the input bitstring, emitting a stream of `Token` values or errors.
   - Responsibilities: skip whitespace, recognise literals (`true`, `false`, `null`), strings (with escape handling), numbers, punctuation (`{}`, `[]`, `,`, `:`).
   - Maintains current byte index for error reporting.
   - Exposes an iterator-style interface so the parser can pull tokens lazily. Initial implementation can return a reversed list for simplicity, but target design uses a custom stream to avoid full materialisation.
   - Utilises helper modules for string decoding and number classification.

2. **Parser (`glason/decoder/parser`)**
   - Consumes tokens to build `Value` instances using a stack-based state machine.
   - Tracks container stack (`Array`, `Object(key_pending)`, `Object(value_pending)`, etc.) replicating Jason's `@array`, `@object`, `@key` markers.
   - Applies option functions:
     - `key_mode`: transforms string keys post-parse.
     - `string_mode`: decides whether to copy or reference sub-binaries.
     - `float_mode`: determines numeric representation when encountering scalars.
     - `object_mode`: constructs `Value.Object` or `Value.OrderedObject` accordingly.
   - Raises descriptive `DecodeError` with byte position on unexpected tokens or premature EOF.

3. **Support Modules**
   - `glason/decoder/number`: parse binary segments into `Int`/`Float`, including overflow and invalid digit detection.
   - `glason/decoder/string`: handle escape sequences, unicode surrogate pairs, optional copying behaviour.
   - `glason/decoder/state`: (optional) define parser stack enums for clarity.

## Data Flow
```
BitString -> tokenizer (TokenStream) -> parser state machine -> Value
```
- Parser fetches next token when needed; tokenizer holds offset and returns `Result(#(Token, TokenizerState), DecodeError)`.
- Final implementation will avoid constructing the entire token list, but early milestones can use list accumulation for simpler validation.

## Error Reporting Strategy
- `DecodeError` fields:
  - `position`: byte offset measured from input start.
  - `token`: optional string representation of offending bytes.
  - `message`: human-readable description.
  - `reason`: enum for structured matching.
- Tokenizer emits precise offsets; parser propagates or enriches them when context-specific errors occur.

## Next Steps
1. Implement minimal tokenizer supporting whitespace, punctuation, and literals, returning list of tokens for development convenience.
2. Add parser skeleton translating a token list into `Value`, initially handling only trivial inputs (`null`, booleans`, empty arrays/objects`).
3. Expand coverage and introduce streaming-friendly tokenizer once confidence is built.
