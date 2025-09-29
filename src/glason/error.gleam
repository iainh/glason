import gleam/option.{type Option, None}

pub type DecodeErrorReason {
  UnexpectedByte(Int)
  UnexpectedEnd
  UnexpectedToken(String)
  InvalidNumber
  DecodeNotImplemented
  Other(String)
}

pub type DecodeError {
  DecodeError(
    reason: DecodeErrorReason,
    message: String,
    position: Int,
    token: Option(String),
  )
}

pub fn not_implemented_decode_error() -> DecodeError {
  DecodeError(DecodeNotImplemented, "decoder not implemented yet", 0, None)
}

pub fn decode_error(
  reason: DecodeErrorReason,
  message: String,
  position: Int,
  token: Option(String),
) -> DecodeError {
  DecodeError(reason, message, position, token)
}

pub type EncodeErrorReason {
  DuplicateKey(String)
  InvalidByte(Int)
  NotRepresentable(String)
  EncodeNotImplemented
  OtherEncode(String)
}

pub type EncodeError {
  EncodeError(reason: EncodeErrorReason, message: String)
}

pub fn not_implemented_encode_error() -> EncodeError {
  EncodeError(EncodeNotImplemented, "encoder not implemented yet")
}

pub fn encode_error(reason: EncodeErrorReason, message: String) -> EncodeError {
  EncodeError(reason, message)
}
