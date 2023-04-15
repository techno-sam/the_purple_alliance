import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/widgets.dart';
import 'package:the_purple_alliance/data_manager.dart';

abstract class JsonWidgetBuilder {
  JsonWidgetBuilder.fromJson(Map<String, dynamic> schemeData);
  Widget build(BuildContext context);
}

enum TextType {
  standard,
  heading
}

class TextWidgetBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;
  String? _style;

  TextType get style => _style == null ? TextType.standard : (TextType.values.firstWhere((element) => element.name == _style, orElse: () => TextType.standard));

  TextWidgetBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
    if (schemeData.containsKey("style")) {
      _style = schemeData["style"];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    switch (style) {
      case TextType.heading:
        child = Column(
          children: [
            Divider(
              color: Colors.grey.shade700,
              thickness: 0.5,
              indent: 25,
              endIndent: 25,
            ),
            Text(_label, style: theme.textTheme.titleLarge),
            const Divider(color: Colors.black),
          ],
        );
        break;
      default:
        child = Text(_label);
        break;
    }
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: child,
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

abstract class LabeledAndPaddedSynchronizedBuilder<T extends DataValue> extends SynchronizedBuilder<T> {
  late final String _label;
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

class TextFieldWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<TextDataValue> {

  late final TextEditingController _controller;
  TextFieldWidgetBuilder.fromJson(super.schemeData) : super.fromJson() {
    _controller = TextEditingController(text: _dataValue?.value ?? TextDataValue.getDefault());
  }

  @override
  Widget build(BuildContext context) {
    _controller.text = _dataValue?.value ?? TextDataValue.getDefault();
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
            controller: _controller,
//            initialValue: _dataValue?.value ?? TextDataValue.getDefault(),
            onChanged: (value) {
              _dataValue?.value = value;
            },
          );
        }
      ),
    );
  }
}

class DropdownWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<DropdownDataValue> {
  DropdownWidgetBuilder.fromJson(super.schemeData) : super.fromJson();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return DropdownButtonFormField(
            key: Key(_key),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: _label,
            ),
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
                log("Set dropdown value to $value");
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

class StarRatingWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<StarRatingDataValue> {
  StarRatingWidgetBuilder.fromJson(super.schemeData) : super.fromJson();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
//          log("Building star $_key, personal value: ${_dataValue?.personalValue}");
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label),
              const SizedBox(height: 2),
              StarRating(
                key: Key("$_key:rating_${_dataValue?.personalValue}"),
                initialRating: _dataValue?.personalValue ?? 0,
                averageRating: _dataValue?.averageValue,
                onChanged: (value) {
                  _dataValue?.personalValue = value;
                },
                color: Colors.amber,
              ),
            ],
          );
        },
      ),
    );
  }
}

class CommentsWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<CommentsDataValue> {
  late final TextEditingController _controller;
  CommentsWidgetBuilder.fromJson(super.schemeData) : super.fromJson() {
    _controller = TextEditingController(text: _dataValue?.personalComment ?? CommentsDataValue.getDefault());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    var heroTag = "comment_title_$_label:$_key";
    _controller.text = _dataValue?.personalComment ?? CommentsDataValue.getDefault();
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Card(
          color: theme.colorScheme.primaryContainer,
          child: Container(
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Hero(tag: heroTag, child: Text(_label, style: theme.textTheme.headlineSmall)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: ((context) {
                                return Scaffold(
                                  appBar: AppBar(
                                    backgroundColor: theme.primaryColorDark,
                                    title: Hero(tag: heroTag, child: Text(_label, style: theme.textTheme.headlineSmall)),
                                    centerTitle: true,
                                  ),
                                  body: Center(
                                    child: CommentList(
                                      theme: theme,
                                      comments: (_dataValue?.stringComments ?? {})..[appState.username] = _dataValue?.personalComment ?? "",
                                    ),
                                  ),
                                );
                              })
                          )
                      );
                    },
                    icon: const Icon(Icons.view_stream),
                    label: const Text("View All Comments"),
                  ),
                  const Divider(),
                  Text("Your comment", style: theme.textTheme.labelMedium),
                  TextFormField(
                    key: Key(_key),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    controller: _controller,
//                    initialValue: _dataValue?.personalComment ?? CommentsDataValue.getDefault(),
                    onChanged: (value) {
                      _dataValue?.personalComment = value;
                    },
                  )
                ],
              )
          )
      ),
    );
  }
}

class PhotosBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;

  PhotosBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
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
    var appState = context.watch<MyAppState>();
    var heroTag = "photos_$_label";
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Card(
          color: theme.colorScheme.primaryContainer,
          child: Container(
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Hero(tag: heroTag, child: Text(_label, style: theme.textTheme.headlineSmall)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () {
                      appState.imageSyncManager.addToDownload(appState.imageSyncManager.notDownloaded);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: ((context) {
                                return PhotosPage(heroTag, _label, appState.builder?.currentTeam ?? 0);
                              })
                          )
                      );
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text("View Photos"),
                  ),
                  /*const Divider(),
                  Text("Your comment", style: theme.textTheme.labelMedium),
                  TextFormField(
                    key: Key(_key),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    controller: _controller,
//                    initialValue: _dataValue?.personalComment ?? CommentsDataValue.getDefault(),
                    onChanged: (value) {
                      _dataValue?.personalComment = value;
                    },
                  )*/
                ],
              )
          )
      ),
    );
  }
}

Map<String, JsonWidgetBuilder Function(Map<String, dynamic>)> widgetBuilders = {};

void initializeBuilders() {
  widgetBuilders.clear();
  widgetBuilders["text"] = TextWidgetBuilder.fromJson;
  widgetBuilders["photos"] = PhotosBuilder.fromJson;
  widgetBuilders["text_field"] = TextFieldWidgetBuilder.fromJson;
  widgetBuilders["dropdown"] = DropdownWidgetBuilder.fromJson;
  widgetBuilders["star_rating"] = StarRatingWidgetBuilder.fromJson;
  widgetBuilders["comments"] = CommentsWidgetBuilder.fromJson;
  initializeValueHolders();
}

ExperimentBuilder? safeLoadBuilder(List<dynamic> data) {
  try {
    return ExperimentBuilder.fromJson(data);
  } catch (e) {
    log('$e');
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