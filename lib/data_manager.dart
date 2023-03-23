
import 'dart:convert';

final Map<Type, DataValue Function()> valueTypes = {};

abstract class DataValue {
  void fromJson(dynamic data);
  
  static dynamic load(dynamic data, Type t) {
    if (valueTypes.containsKey(t)) {
      return valueTypes[t]!();
    } else {
      throw "Type $t is not registered";
    }
  }
  dynamic toJson();
  void reset();
}

class TextDataValue implements DataValue {

  String _value = "";

  @override
  void fromJson(dynamic data) {
    assert (data is String);
    _value = data;
  }

  @override
  toJson() {
    return _value;
  }

  @override
  void reset() {
    _value = "";
  }
}

void initializeValueHolders() {
  valueTypes.clear();
  valueTypes[TextDataValue] = TextDataValue.new;
}

class DataManager {
  final Map<String, DataValue> values = {};

  void load(Map<String, dynamic>? data) {
    if (data != null) {
      for (MapEntry<String, DataValue> entry in values.entries) {
        if (data.containsKey(entry.key)) {
          entry.value.fromJson(data[entry.key]);
        } else {
          entry.value.reset();
        }
      }
    } else {
      for (DataValue value in values.values) {
        value.reset();
      }
    }
  }

  Map<String, dynamic> save() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      data[entry.key] = entry.value.toJson();
    }
    return data;
  }
}