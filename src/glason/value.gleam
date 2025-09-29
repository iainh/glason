import gleam/option.{type Option, None, Some}

pub type Value {
  Null
  Bool(Bool)
  String(String)
  Int(Int)
  Float(Float)
  Array(List(Value))
  Object(List(#(String, Value)))
  Ordered(OrderedObject)
}

pub type OrderedObject {
  OrderedObject(List(#(String, Value)))
}

pub fn ordered_object(values: List(#(String, Value))) -> OrderedObject {
  OrderedObject(values)
}

pub fn ordered_object_to_list(object: OrderedObject) -> List(#(String, Value)) {
  let OrderedObject(values) = object
  values
}

pub fn ordered_object_get(object: OrderedObject, key: String) -> Option(Value) {
  ordered_object_search(ordered_object_to_list(object), key)
}

fn ordered_object_search(values: List(#(String, Value)), key: String) -> Option(Value) {
  case values {
    [] -> None
    [#(current_key, value), ..rest] ->
      case current_key == key {
        True -> Some(value)
        False -> ordered_object_search(rest, key)
      }
  }
}
