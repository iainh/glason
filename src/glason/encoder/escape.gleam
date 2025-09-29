import gleam/int
import gleam/list
import gleam/string
import gleam/string_builder
import glason/options

pub fn escape_string(input: String, mode: options.EscapeMode) -> String {
  case mode {
    options.EscapeJson -> escape_json(input)
    options.EscapeJavascriptSafe -> escape_javascript(input)
    options.EscapeHtmlSafe -> escape_html(input)
    options.EscapeUnicodeSafe -> escape_unicode(input)
  }
}

fn escape_json(input: String) -> String {
  escape_with(input, escape_json_codepoint)
}

fn escape_javascript(input: String) -> String {
  escape_with(input, fn(codepoint) {
    case codepoint {
      0x2028 -> Special("\\u2028")
      0x2029 -> Special("\\u2029")
      _ -> escape_json_codepoint(codepoint)
    }
  })
}

fn escape_html(input: String) -> String {
  escape_with(input, fn(codepoint) {
    case codepoint {
      60 -> Special("\\u003C") // <
      62 -> Special("\\u003E") // >
      38 -> Special("\\u0026") // &
      39 -> Special("\\u0027") // '
      _ -> escape_json_codepoint(codepoint)
    }
  })
}

fn escape_unicode(input: String) -> String {
  escape_with(input, fn(codepoint) {
    case codepoint {
      _ if codepoint > 0x7F -> Special(unicode_escape(codepoint))
      _ -> escape_json_codepoint(codepoint)
    }
  })
}

type EscapeResult {
  Literal(Int)
  Special(String)
}

fn escape_with(input: String, mapper: fn(Int) -> EscapeResult) -> String {
  let builder =
    input
    |> string.to_utf_codepoints()
    |> list.fold(string_builder.new(), fn(acc, cp) {
      let codepoint = string.utf_codepoint_to_int(cp)
      case mapper(codepoint) {
        Literal(cp) -> string_builder.append(acc, codepoint_to_string(cp))
        Special(text) -> string_builder.append(acc, text)
      }
    })

  string_builder.to_string(builder)
}

fn escape_json_codepoint(codepoint: Int) -> EscapeResult {
  case codepoint {
    34 -> Special("\\\"")
    92 -> Special("\\\\")
    8 -> Special("\\b")
    12 -> Special("\\f")
    10 -> Special("\\n")
    13 -> Special("\\r")
    9 -> Special("\\t")
    cp if cp < 0x20 -> Special(unicode_escape(cp))
    other -> Literal(other)
  }
}

fn unicode_escape(codepoint: Int) -> String {
  case codepoint {
    cp if cp <= 0xFFFF -> {
      let hex = string.uppercase(int.to_base16(cp))
      "\\u" <> pad_left(hex)
    }
    cp -> {
      let adjusted = cp - 0x10000
      let high = 0xD800 + adjusted / 0x400
      let low = 0xDC00 + adjusted % 0x400
      unicode_escape(high) <> unicode_escape(low)
    }
  }
}

fn pad_left(text: String) -> String {
  let length = string.length(text)
  case length {
    4 -> text
    3 -> "0" <> text
    2 -> "00" <> text
    1 -> "000" <> text
    _ -> text
  }
}

fn codepoint_to_string(codepoint: Int) -> String {
  case string.utf_codepoint(codepoint) {
    Ok(cp) -> string.from_utf_codepoints([cp])
    Error(_) -> ""
  }
}
