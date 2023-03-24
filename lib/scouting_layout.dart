import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'widgets.dart';
import 'data_manager.dart';

abstract class JsonWidgetBuilder {
  JsonWidgetBuilder.fromJson(Map<String, dynamic> displayData);
  Widget build(BuildContext context);
}

class TextWidgetBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;
  TextWidgetBuilder.fromJson(Map<String, dynamic> displayData) : super.fromJson(displayData) {
    _label = displayData["label"];
    if (displayData.containsKey("padding")) {
      var padding = displayData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Text(_label),
    );
  }
}

abstract class SynchronizedBuilder<T extends DataValue> extends JsonWidgetBuilder {
  DataManager? _manager;

  T? get _dataValue {
    var value = _manager?.values[_key];
    if (value is T) {
      return value;
    }
    return null;
  }

  late final String _key;
  SynchronizedBuilder.fromJson(Map<String, dynamic> displayData) : super.fromJson(displayData) {
    _key = displayData["key"];
  }

  void setDataManager(DataManager? manager) {
    _manager = manager;
    if (manager != null && !manager.values.containsKey(_key)) {
      manager.values[_key] = DataValue.load(T);
    }
  }
}

class TextFieldWidgetBuilder extends SynchronizedBuilder<TextDataValue> {
  late final String _label;
  double? _padding;
  TextFieldWidgetBuilder.fromJson(Map<String, dynamic> displayData) : super.fromJson(displayData) {
    _label = displayData["label"];
    if (displayData.containsKey("padding")) {
      var padding = displayData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return TextFormField(
            key: Key(_key),
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              labelText: _label,
            ),
            initialValue: _dataValue?.value ?? TextDataValue.getDefault(),
            onChanged: (value) {
              _dataValue?.value = value;
            },
          );
        }
      ),
    );
  }
}

Map<String, JsonWidgetBuilder Function(Map<String, dynamic>)> widgetBuilders = {};

void initializeBuilders() {
  widgetBuilders.clear();
  widgetBuilders["text"] = TextWidgetBuilder.fromJson;
  widgetBuilders["text_field"] = TextFieldWidgetBuilder.fromJson;
  initializeValueHolders();
}

ExperimentBuilder? safeLoadBuilder(String data) {
  try {
    return ExperimentBuilder.fromJson(data);
  } catch (e) {
    print(e);
    return null;
  }
}

JsonWidgetBuilder? loadBuilder(Map<String, dynamic> entry) {
  if (entry.containsKey("type")) {
    String type = entry["type"];
    if (widgetBuilders.containsKey(type) && widgetBuilders[type] != null) {
      return widgetBuilders[type]!(entry);
    } else {
      throw "Undefined type: $type in $entry";
    }
  } else {
    throw "Missing type key in $entry";
  }
}

class ExperimentBuilder {

  final List<JsonWidgetBuilder> _builders = [];
  final TeamDataManager teamManager = TeamDataManager();
  DataManager? _manager;

  DataManager? get manager => _manager;

  int? _currentTeam;

  int? get currentTeam => _currentTeam;

  ExperimentBuilder.fromJson(String data) {
    var jdat = jsonDecode(data);
    if (jdat is List<dynamic>) {
      for (Map<String, dynamic> entry in jdat) {
        var builder = loadBuilder(entry);
        if (builder != null) {
          _builders.add(builder);
//          if (builder is SynchronizedBuilder) {
//            builder.setDataManager(manager);
//          }
        }
      }
    } else {
      throw "Invalid Json type $jdat (type: ${jdat.runtimeType})";
    }
  }

  void setTeam(int teamNumber) {
    _currentTeam = teamNumber;
    _manager = teamManager.getManager(teamNumber);
    for (JsonWidgetBuilder builder in _builders) {
      if (builder is SynchronizedBuilder) {
        builder.setDataManager(manager);
        builder._dataValue?.setChangeNotifier(_changeNotifier);
      }
    }
  }

  List<Widget> build(BuildContext context) {
    return _currentTeam == null ?
    [
      Center(
        child: SizedBox(
          child: DisplayCard(
            text: "No team selected",
          ),
        ),
      )
    ] :
    [
      for (JsonWidgetBuilder builder in _builders)
        builder.build(context),
    ];
  }

  void Function() _changeNotifier = () {};

  void setChangeNotifier(void Function() changeNotifier) {
    _changeNotifier = changeNotifier;
  }
}

List<Widget> buildExperiment(BuildContext context, ExperimentBuilder? builder) {
  if (builder != null) {
    return builder.build(context);
  }
  final theme = Theme.of(context);
  return [
    Center(
      child: DisplayCard(
          text: "Not loaded",
          icon: Icon(
            Icons.error_outline,
            color: theme.colorScheme.onPrimary,
          )
      ),
    )
  ];
}