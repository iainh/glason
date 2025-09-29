import gleam/list

pub type KeyMode {
  KeysStrings
  KeysAtoms
  KeysExistingAtoms
  KeysCustom(fn(String) -> String)
}

pub type StringMode {
  StringsReference
  StringsCopy
}

pub type FloatMode {
  FloatsNative
  FloatsDecimals
}

pub type ObjectMode {
  ObjectsMaps
  ObjectsOrdered
}

pub type EscapeMode {
  EscapeJson
  EscapeJavascriptSafe
  EscapeHtmlSafe
  EscapeUnicodeSafe
}

pub type MapMode {
  MapsNaive
  MapsStrict
}

pub type PrettyMode {
  PrettyDisabled
  PrettyDefault
}

pub type DecodeOptions {
  DecodeOptions(
    key_mode: KeyMode,
    string_mode: StringMode,
    float_mode: FloatMode,
    object_mode: ObjectMode,
    map_mode: MapMode,
  )
}

pub type EncodeOptions {
  EncodeOptions(escape_mode: EscapeMode, map_mode: MapMode, pretty: PrettyMode)
}

pub type Options {
  Options(decode: DecodeOptions, encode: EncodeOptions)
}

pub fn default_decode_options() -> DecodeOptions {
  DecodeOptions(
    key_mode: KeysStrings,
    string_mode: StringsReference,
    float_mode: FloatsNative,
    object_mode: ObjectsMaps,
    map_mode: MapsNaive,
  )
}

pub fn default_encode_options() -> EncodeOptions {
  EncodeOptions(
    escape_mode: EscapeJson,
    map_mode: MapsNaive,
    pretty: PrettyDisabled,
  )
}

pub fn default_options() -> Options {
  Options(default_decode_options(), default_encode_options())
}

pub fn set_key_mode(options: DecodeOptions, mode: KeyMode) -> DecodeOptions {
  let DecodeOptions(_, string_mode, float_mode, object_mode, map_mode) = options
  DecodeOptions(mode, string_mode, float_mode, object_mode, map_mode)
}

pub fn set_string_mode(
  options: DecodeOptions,
  mode: StringMode,
) -> DecodeOptions {
  let DecodeOptions(key_mode, _, float_mode, object_mode, map_mode) = options
  DecodeOptions(key_mode, mode, float_mode, object_mode, map_mode)
}

pub fn set_float_mode(options: DecodeOptions, mode: FloatMode) -> DecodeOptions {
  let DecodeOptions(key_mode, string_mode, _, object_mode, map_mode) = options
  DecodeOptions(key_mode, string_mode, mode, object_mode, map_mode)
}

pub fn set_object_mode(
  options: DecodeOptions,
  mode: ObjectMode,
) -> DecodeOptions {
  let DecodeOptions(key_mode, string_mode, float_mode, _, map_mode) = options
  DecodeOptions(key_mode, string_mode, float_mode, mode, map_mode)
}

pub fn set_decode_map_mode(
  options: DecodeOptions,
  mode: MapMode,
) -> DecodeOptions {
  let DecodeOptions(key_mode, string_mode, float_mode, object_mode, _) = options
  DecodeOptions(key_mode, string_mode, float_mode, object_mode, mode)
}

pub fn set_escape_mode(
  options: EncodeOptions,
  mode: EscapeMode,
) -> EncodeOptions {
  let EncodeOptions(_, map_mode, pretty) = options
  EncodeOptions(mode, map_mode, pretty)
}

pub fn set_map_mode(options: EncodeOptions, mode: MapMode) -> EncodeOptions {
  let EncodeOptions(escape_mode, _, pretty) = options
  EncodeOptions(escape_mode, mode, pretty)
}

pub fn set_pretty_mode(
  options: EncodeOptions,
  mode: PrettyMode,
) -> EncodeOptions {
  let EncodeOptions(escape_mode, map_mode, _) = options
  EncodeOptions(escape_mode, map_mode, mode)
}

pub fn merge_decode_options(
  base: DecodeOptions,
  overrides: List(fn(DecodeOptions) -> DecodeOptions),
) -> DecodeOptions {
  list.fold(overrides, base, fn(current, apply) { apply(current) })
}

pub fn merge_encode_options(
  base: EncodeOptions,
  overrides: List(fn(EncodeOptions) -> EncodeOptions),
) -> EncodeOptions {
  list.fold(overrides, base, fn(current, apply) { apply(current) })
}
