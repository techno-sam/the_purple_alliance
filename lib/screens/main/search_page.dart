import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/widgets/scouting/builders/abstract_synchronized_builder.dart';
import 'package:the_purple_alliance/state/search_system.dart';
import 'package:the_purple_alliance/widgets/search/rankings_dialog.dart';
import 'package:the_purple_alliance/widgets/search/search_configuration_selection.dart';
import 'package:the_purple_alliance/widgets/search/search_field_picker_dialog.dart';

import '../../main.dart';

/*
Search and ranking system works as a total points system
each data value emits a number of points for the current state and the total number of points
if a data value wishes to be searchable, it must implement SearchDataEmitter
 */
class SearchPage extends StatefulWidget {
  const SearchPage(this._viewTeamPage, {super.key});

  final void Function() _viewTeamPage;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (String searchKey in appState.searchValues?.keys ?? [])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Icon(appState.builder?.getBuilder(searchKey)?.icon),
                                  const SizedBox(width: 8),
                                  Text(
                                    appState.builder?.getBuilder(searchKey)?.label ?? "???",
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    appState.searchValues?.remove(searchKey);
                                  });
                                },
                              )//Icon(Icons.delete)
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  if (getWindowType(context) <= AdaptiveWindowType.small)
                                    const SizedBox(height: 25),
                                  appState.builder?.getBuilder(searchKey)?.buildSearchEditor(context) ?? const Text("Failed to build"),
                                ],
                              )
                            )
                          ],
                        )
                      )
                    )
                ],
              ),
            ),
          ),
          (getWindowType(context) >= AdaptiveWindowType.medium ? Row.new : Column.new)(
            mainAxisAlignment: getWindowType(context) >= AdaptiveWindowType.medium ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
            mainAxisSize: getWindowType(context) >= AdaptiveWindowType.medium ? MainAxisSize.max : MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  GlobalKey<FormFieldState<String>> nameKey = GlobalKey<FormFieldState<String>>();
                  String? newName = await showDialog(context: context, builder: (context) {
                    return SearchConfigurationSelection(appState: appState, theme: theme, nameKey: nameKey);
                  });
                  //print("Result: ${newName}");
                  if (newName == null || newName == "") {
                    return;
                  }
                  setState(() {
                    appState.currentSearchConfiguration = newName;
                  });
                },
                icon: const Icon(Icons.file_open),
                label: const Text("Load parameters")
              ),
              if (appState.searchValues != null)
              ElevatedButton.icon(
                onPressed: () async {
                  String? chosenKey = await showDialog(
                    context: context,
                    builder: (context) {
                      var appState = context.watch<MyAppState>();
                      List<SynchronizedBuilder> builders = appState.builder?.getAllSearchableBuilders() ?? [];
                      final theme = Theme.of(context);
                      return SearchFieldPickerDialog(builders: builders, appState: appState, theme: theme);
                    }
                  );
                  //log("Chosen key: $chosenKey");
                  if (chosenKey != null) {
                    var defaultConfig = appState.builder?.getSearchableValue(chosenKey)?.defaultConfig;
                    if (defaultConfig != null) {
                      setState(() {
                        appState.searchValues?[chosenKey] = defaultConfig;
                      });
                    }
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Parameter")
              ),
              if (appState.searchValues != null)
              ElevatedButton.icon(
                onPressed: () {
                  var teamDataManager = appState.builder?.allManagers;
                  if (teamDataManager != null && appState.searchValues != null) {
                    List<int> rankedTeams = teamDataManager.getRankedTeams(appState.searchValues!);
                    //print(rankedTeams);
                    showDialog(context: context, builder: (context) {
                      final theme = Theme.of(context);
                      return RankingsDialog(
                        theme: theme,
                        rankedTeams: rankedTeams,
                        dataManagers: teamDataManager,
                        appState: appState,
                        viewTeamPage: widget._viewTeamPage
                      );
                    });
                  }
                },
                icon: const Icon(Icons.search),
                label: Text("Search '${appState.currentSearchConfiguration ?? ""}'")
              )
            ],
          )
        ],
      )
    );
  }
}