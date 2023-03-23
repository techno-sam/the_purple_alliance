import 'dart:convert';

import 'package:flutter/material.dart';
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
  late T _dataValue;
  late final String _key;
  SynchronizedBuilder.fromJson(Map<String, dynamic> displayData, dynamic valueData) : super.fromJson(displayData) {
    _dataValue = DataValue.load(valueData, T);
    _key = displayData["key"];
  }

  void register(DataManager manager) {
    manager.values[_key] = _dataValue;
  }
}

class TextFieldWidgetBuilder extends SynchronizedBuilder<TextDataValue> {
  late final String _label;
  double? _padding;
  TextFieldWidgetBuilder.fromJson(Map<String, dynamic> displayData, dynamic valueData) : super.fromJson(displayData, valueData) {
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
      child: TextFormField(
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          labelText: _label,
        ),
      ),
    );
  }
}

Map<String, JsonWidgetBuilder Function(Map<String, dynamic>)> widgetBuilders = {};
Map<String, SynchronizedBuilder Function(Map<String, dynamic>, dynamic)> synchronizedBuilders = {};

void initializeBuilders() {
  widgetBuilders.clear();
  synchronizedBuilders.clear();
  widgetBuilders["text"] = TextWidgetBuilder.fromJson;
  synchronizedBuilders["text_field"] = TextFieldWidgetBuilder.fromJson;
  initializeValueHolders();
}

ExperimentBuilder? safeLoadBuilder(String data) {
  try {
    return ExperimentBuilder.fromJson(data);
  } catch (e) {
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
  final DataManager _manager = DataManager();

  ExperimentBuilder.fromJson(String data) {
    var jdat = jsonDecode(data);
    if (jdat is List<dynamic>) {
      for (Map<String, dynamic> entry in jdat) {
        var builder = loadBuilder(entry);
        if (builder != null) {
          _builders.add(builder);
          if (builder is SynchronizedBuilder) {
            builder.register(_manager);
          }
        }
      }
    } else {
      throw "Invalid Json type $jdat (type: ${jdat.runtimeType})";
    }
  }

  List<Widget> build(BuildContext context) {
    return [
      for (JsonWidgetBuilder builder in _builders)
        builder.build(context),
    ];
  }
}

List<Widget> buildExperiment(BuildContext context, ExperimentBuilder? builder) {
  if (builder != null) {
    return builder.build(context);
  }
  final theme = Theme.of(context);
  return [
    DisplayCard(
        text: "Not loaded",
        icon: Icon(
          Icons.error_outline,
          color: theme.colorScheme.onPrimary,
        )
    )
  ];
}