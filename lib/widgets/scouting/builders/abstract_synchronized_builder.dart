import 'package:the_purple_alliance/state/data_values/abstract_data_value.dart';
import 'package:the_purple_alliance/state/team_specific_data_manager.dart';

import 'abstract_builder.dart';

abstract class SynchronizedBuilder<T extends DataValue> extends JsonWidgetBuilder {
  TeamSpecificDataManager? _manager;

  T? get dataValue {
    var value = _manager?.values[_key];
    if (value is T) {
      return value;
    }
    return null;
  }

  late final String _key;
  String get key => _key;
  late final Map<String, dynamic> _initData;
  SynchronizedBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _key = schemeData["key"];
    _initData = Map.unmodifiable(schemeData);
  }

  void setDataManager(TeamSpecificDataManager? manager) {
    _manager = manager;
    if (manager != null) {
      initDataManager(manager);
    }
  }

  void initDataManager(TeamSpecificDataManager manager) {
    if (!manager.values.containsKey(_key)) {
      manager.values[_key] = DataValue.load(T, _initData);
    }
  }
}

abstract class LabeledAndPaddedSynchronizedBuilder<T extends DataValue> extends SynchronizedBuilder<T> {
  late final String _label;
  @override
  String get label => _label;

  double? _padding;
  double? get padding => _padding;
  LabeledAndPaddedSynchronizedBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
  }
}