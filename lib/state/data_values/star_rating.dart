import '../search_system.dart';
import 'abstract_data_value.dart';

class StarRatingDataValue extends DataValue with TimestampSpecialBehaviorMixin implements SearchDataEmitter {
  double? _personalValue;
  double? get personalValue => _personalValue;
  set personalValue(double? value) {
    _personalValue = value;
    markChange();
  }

  double? averageValue;
  bool? _single;
  bool get single => _single == true;

  StarRatingDataValue();

  @override
  void fromJson(data) {
    assert (data is Map<String, dynamic>);
    _personalValue = data["personal_value"];
    averageValue = data["average_value"];
    _single = data["single"];
  }

  @override
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk) {
    assert (data is Map<String, dynamic>);
    // we always set the average value, since that is server-calculated
    // we only set the personal value if it is newer than the local value, or if the local value does not exist
    averageValue = data["average_value"];
    _single = data["single"];
    if (localOld || _personalValue == null) {
      _personalValue = data["personal_value"];
      return false; // data is now completely from the server, update timestamp to match
    }
    return true; // our data is still potentially unique, keep the timestamp
  }

  @override
  bool fromJsonBackup(dynamic data, bool fromDisk) {
    fromJson(data);
    return false; // data is now completely from the server, update timestamp to match
  }

  @override
  toJson() {
    return {
      "personal_value": _personalValue,
      "average_value": averageValue, // this is, of course, ignored by the server and overridden with a more accurate average value - the server also overrides the time-based system
      "single": single,
    };
  }

  @override
  int getCurrentPoints(dynamic config) => (getMaxPoints(config) * (averageValue ?? 0) / 5).floor();

  @override
  int getMaxPoints(dynamic config) => averageValue == null ? 0 : config as int;

  @override
  int get defaultConfig => 0;
}