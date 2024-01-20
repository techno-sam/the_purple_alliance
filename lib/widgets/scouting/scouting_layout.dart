import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/all_data_managers.dart';
import 'package:the_purple_alliance/state/data_values/abstract_data_value.dart';
import 'package:the_purple_alliance/state/search_system.dart';
import 'package:the_purple_alliance/state/team_specific_data_manager.dart';
import 'package:the_purple_alliance/widgets/display_card.dart';
import 'package:the_purple_alliance/widgets/scouting/builders/default_placeholder_builder.dart';
import 'package:the_purple_alliance/widgets/scouting/json_builder_holder.dart';

import 'builders/abstract_builder.dart';
import 'builders/abstract_synchronized_builder.dart';
import 'builders/comments_builder.dart';
import 'builders/dropdown_builder.dart';
import 'builders/photos_builder.dart';
import 'builders/star_rating_builder.dart';
import 'builders/text_builder.dart';
import 'builders/text_field_builder.dart';
import 'builders/win_loss_builder.dart';

Map<String, JsonWidgetBuilder Function(Map<String, dynamic>)> widgetBuilders = {};

void initializeBuilders() {
  widgetBuilders.clear();
  widgetBuilders["text"] = TextWidgetBuilder.fromJson;
  widgetBuilders["photos"] = PhotosBuilder.fromJson;
  widgetBuilders["text_field"] = TextFieldWidgetBuilder.fromJson;
  widgetBuilders["dropdown"] = DropdownWidgetBuilder.fromJson;
  widgetBuilders["star_rating"] = StarRatingWidgetBuilder.fromJson;
  widgetBuilders["comments"] = CommentsWidgetBuilder.fromJson;
  widgetBuilders["win_loss"] = WinLossBuilder.fromJson;
  initializeValueHolders();
}

ScoutingBuilder? safeLoadBuilder(List<dynamic> data) {
  try {
    return ScoutingBuilder.fromJson(data);
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
      log("Undefined type: $type in $entry, returning default builder");
      return DefaultPlaceholderBuilder.fromJson(entry, type);
    }
  } else {
    throw "Missing type key in $entry";
  }
}

class ScoutingBuilder {

  final List<JsonWidgetBuilder> _builders = [];
  final Map<String, JsonWidgetBuilder> _builderMap = {};
  late final AllDataManagers allManagers;
  TeamSpecificDataManager? _manager;

  TeamSpecificDataManager? get manager => _manager;

  int? _currentTeam;

  int? get currentTeam => _currentTeam;

  List<SynchronizedBuilder> getAllSearchableBuilders() {
    return _builders.whereType<SynchronizedBuilder>().where((element) => element.dataValue is SearchDataEmitter).toList();
  }

  DataValue? getSearchableDataValue(String key) {
    var builder = _builderMap[key];
    if (builder is SynchronizedBuilder && builder.dataValue is SearchDataEmitter) {
      return builder.dataValue;
    }
    return null;
  }

  SearchDataEmitter? getSearchableValue(String key) {
    var builder = _builderMap[key];
    if (builder is SynchronizedBuilder && builder.dataValue is SearchDataEmitter) {
      return builder.dataValue as SearchDataEmitter;
    }
    return null;
  }

  T? getBuilder<T extends JsonWidgetBuilder>(String key) {
    var builder = _builderMap[key];
    return builder is T ? builder : null;
  }

  ScoutingBuilder.fromJson(List<dynamic> data) {
    allManagers = AllDataManagers((m) {
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
        if (entry["key"] is String) {
          _builderMap[entry["key"]] = builder;
        }
      }
    }
  }

  void setTeam(int teamNumber) {
    _currentTeam = teamNumber;
    _manager = allManagers.getManager(teamNumber);
    for (JsonWidgetBuilder builder in _builders) {
      if (builder is SynchronizedBuilder) {
        builder.setDataManager(_manager);
        builder.dataValue?.setChangeNotifier(_changeNotifier);
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
    _changeNotifier();
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
        JsonBuilderHolder(builder: builder),
    ];
  }

  void Function() _changeNotifier = () {};

  void setChangeNotifier(void Function() changeNotifier) {
    _changeNotifier = changeNotifier;
  }
}

List<Widget> buildScoutingLayout(BuildContext context, ScoutingBuilder? builder, void Function() goToTeamSelectionPage) {
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
            color: !oldColors ? null : theme.colorScheme.onPrimary,
          )
      ),
    )
  ];
}