import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/widgets.dart';
import 'package:the_purple_alliance/data_manager.dart';

abstract class JsonWidgetBuilder {
  JsonWidgetBuilder.fromJson(Map<String, dynamic> schemeData);
  Widget build(BuildContext context);
}

class TextWidgetBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;
  TextWidgetBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
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
  late final Map<String, dynamic> _initData;
  SynchronizedBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _key = schemeData["key"];
    _initData = Map.unmodifiable(schemeData);
  }

  void setDataManager(DataManager? manager) {
    _manager = manager;
    if (manager != null) {
      initDataManager(manager);
    }
  }

  void initDataManager(DataManager manager) {
    if (!manager.values.containsKey(_key)) {
      manager.values[_key] = DataValue.load(T, _initData);
    }
  }
}

class TextFieldWidgetBuilder extends SynchronizedBuilder<TextDataValue> {
  late final String _label;
  double? _padding;
  TextFieldWidgetBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
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

class DropdownWidgetBuilder extends SynchronizedBuilder<DropdownDataValue> {
  late final String _label;
  double? _padding;
  DropdownWidgetBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return DropdownButtonFormField(
            key: Key(_key),
            items: [
              if (_dataValue != null)
                for (String value in _dataValue!.options)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
            ],
            onChanged: (value) {
              if (value != null) {
                _dataValue?.value = value;
              }
            },
            value: _dataValue?.value,
            dropdownColor: theme.colorScheme.primaryContainer,
          );
        },
      ),
    );
  }
}

Map<String, JsonWidgetBuilder Function(Map<String, dynamic>)> widgetBuilders = {};

void initializeBuilders() {
  widgetBuilders.clear();
  widgetBuilders["text"] = TextWidgetBuilder.fromJson;
  widgetBuilders["text_field"] = TextFieldWidgetBuilder.fromJson;
  widgetBuilders["dropdown"] = DropdownWidgetBuilder.fromJson;
  initializeValueHolders();
}

ExperimentBuilder? safeLoadBuilder(List<dynamic> data) {
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
  late final TeamDataManager teamManager;
  DataManager? _manager;

  DataManager? get manager => _manager;

  int? _currentTeam;

  int? get currentTeam => _currentTeam;

  ExperimentBuilder.fromJson(List<dynamic> data) {
    teamManager = TeamDataManager((m) {
      for (JsonWidgetBuilder builder in _builders) {
        if (builder is SynchronizedBuilder) {
          builder.initDataManager(m);
        }
      }
    });
    for (Map<String, dynamic> entry in data) {
      var builder = loadBuilder(entry);
      if (builder != null) {
        _builders.add(builder);
//          if (builder is SynchronizedBuilder) {
//            builder.setDataManager(manager);
//          }
      }
    }
  }

  void setTeam(int teamNumber) {
    _currentTeam = teamNumber;
    _manager = teamManager.getManager(teamNumber);
    for (JsonWidgetBuilder builder in _builders) {
      if (builder is SynchronizedBuilder) {
        builder.setDataManager(_manager);
        builder._dataValue?.setChangeNotifier(_changeNotifier);
      }
    }
    _manager!.initialized = true;
  }

  void initializeTeam(int team) {
    var previousTeam = _currentTeam;
    setTeam(team);
    if (previousTeam != null) {
      setTeam(previousTeam);
    } else {
      _currentTeam = null;
      _manager = null;
    }
  }

  void initializeValues(Iterable<String> teams) {
    var previousTeam = _currentTeam;
    for (String team in teams) {
      var parsedTeam = int.tryParse(team);
      if (parsedTeam != null) {
        setTeam(parsedTeam);
      }
    }
    if (previousTeam != null) {
      setTeam(previousTeam);
    } else {
      _currentTeam = null;
      _manager = null;
    }
  }

  List<Widget> build(BuildContext context, void Function() goToTeamSelectionPage) {
    return _currentTeam == null ?
    [
      const Center(
        child: SizedBox(
          child: DisplayCard(
            text: "No team selected",
          ),
        ),
      )
    ] :
    [
      Center(
        child: SizedBox(
          child: TappableDisplayCard(
            text: "Team $currentTeam",
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 250));
              goToTeamSelectionPage();
            },
          ),
        ),
      ),
      for (JsonWidgetBuilder builder in _builders)
        builder.build(context),
    ];
  }

  void Function() _changeNotifier = () {};

  void setChangeNotifier(void Function() changeNotifier) {
    _changeNotifier = changeNotifier;
  }
}

List<Widget> buildExperiment(BuildContext context, ExperimentBuilder? builder, void Function() goToTeamSelectionPage) {
  if (builder != null) {
    return builder.build(context, goToTeamSelectionPage);
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