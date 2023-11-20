import 'abstract_data_value.dart';

// cannot be searched
class TextDataValue extends DataValue {

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
    super.reset();
    _value = "";
  }

  static dynamic getDefault() {
    return "";
  }

  String get value => _value;

  set value(String value) {
    _value = value;
    markChange();
  }
}