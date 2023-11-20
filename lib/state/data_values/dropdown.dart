import '../search_system.dart';
import 'abstract_data_value.dart';

int max(Iterable<int> nums) {
  int v = nums.isEmpty ? 0 : nums.first;
  for (int num in nums) {
    if (num > v) {
      v = num;
    }
  }
  return v;
}

// can be searched
class DropdownDataValue extends DataValue implements SearchDataEmitter {
  String _value = "";
  late final List<String> _options;
  late final String _default;
  late final bool canBeOther;
  String _otherValue = "";

  String get otherValue => _otherValue;
  set otherValue(String otherValue) {
    if (_otherValue != otherValue) {
      _otherValue = otherValue;
      markChange();
    }
  }

  DropdownDataValue(Map<String, dynamic> initData) {
    _options = List<String>.from(initData["options"]);
    _value = initData.containsKey("default") ? initData["default"] : _options[0];

    canBeOther = initData.containsKey("other") ? initData["other"] : false;

    if (!(_options.contains(_value) || (_value == "Other" && canBeOther))) {
      _value = _options[0];
    }
    _default = _value;
  }

  @override
  void fromJson(data) {
    assert (data is Map<String, dynamic>);
    String value = data["value"];
    if (_options.contains(value) || (value == "Other" && canBeOther)) {
      _value = value;
    }
    _otherValue = data["other_value"];
  }

  @override
  toJson() {
    return {
      "value": _value,
      "other_value": _otherValue,
    };
  }

  @override
  void reset() {
    super.reset();
    _value = _default;
    _otherValue = "";
  }

  List<String> get options => List.unmodifiable(_options);

  String get value => _value;
  set value(String value) {
    if (_options.contains(value) || (value == "Other" && canBeOther)) {
      _value = value;
      markChange();
    }
  }

  @override
  int getCurrentPoints(dynamic config) => (config as Map<String, int>)[value] ?? 0;

  @override
  int getMaxPoints(dynamic config) {
    Map<String, int> confMap = config as Map<String, int>;
    return confMap.containsKey(value) ? max(confMap.values) : 0;
  }

  @override
  Map<String, int> get defaultConfig => {};
}