import 'package:the_purple_alliance/state/data_values/win_loss.dart';
import 'package:the_purple_alliance/utils/util.dart';

import 'comments.dart';
import 'dropdown.dart';
import 'star_rating.dart';
import 'text.dart';

final Map<Type, DataValue Function(Map<String, dynamic>)> _valueTypes = {};

/// Simplification wrapper for DataValue constructors that do not take any initialization data
DataValue Function(Map<String, dynamic>) _s(DataValue Function() f) {
  return (_) {
    return f();
  };
}

void initializeValueHolders() {
  _valueTypes.clear();
  _valueTypes[TextDataValue] = _s(TextDataValue.new);
  _valueTypes[DropdownDataValue] = DropdownDataValue.new;
  _valueTypes[StarRatingDataValue] = _s(StarRatingDataValue.new);
  _valueTypes[CommentsDataValue] = _s(CommentsDataValue.new);
  _valueTypes[WinLossDataValue] = _s(WinLossDataValue.new);
}

abstract class DataValue {
  int lastEdited = -1;
  bool get localChanges => lastEdited != -1;
  void Function() changeNotifier = () {};
  void fromJson(dynamic data);

  static dynamic load(Type t, Map<String, dynamic> initData) {
    if (_valueTypes.containsKey(t)) {
      return _valueTypes[t]!(initData);
    } else {
      throw "Type $t is not registered";
    }
  }

  dynamic toJson();

  void reset() {
    lastEdited = -1;
  }

  void markChange() {
    lastEdited = generateTimestamp();
  }

  void setChangeNotifier(void Function() changeNotifier) {
    this.changeNotifier = changeNotifier;
  }
}

mixin TimestampSpecialBehaviorMixin on DataValue {
  /// localOld is true if the data is from the server, and the local data is older - if loading from disk and a timestamp is present, localOld will always be true
  ///
  /// Returns true if the current timestamp should be kept, returns false if it should be set to -1
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk);

  /// Only called if no timestamp is present in the read data
  ///
  /// Returns true if the current timestamp should be kept, returns false if it should be set to -1
  bool fromJsonBackup(dynamic data, bool fromDisk);
}