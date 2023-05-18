import 'dart:developer';

import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/scouting_layout.dart';
import 'package:the_purple_alliance/search_system.dart';

import 'main.dart';

/*
Search and ranking system works as a total points system
each data value emits a number of points for the current state and the total number of points
if a data value wishes to be searchable, it must implement SearchDataEmitter
 */
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  GlobalKey<FormFieldState<String>> nameKey = GlobalKey<FormFieldState<String>>();
                  String? newName = await showDialog(context: context, builder: (context) {
                    return SimpleDialog(
                      title: const Text("Select search configuration"),
                      children: [
                        SizedBox(
                          height: 350,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (String conf in appState.searchConfigurations.keys)
                                  Card(
                                    elevation: 2,
                                    child: InkWell(
                                      customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
                                      onTap: () {
                                        Navigator.pop(context, conf);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                        child: Text(conf),
                                      ),
                                    )
                                  )
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                child: TextFormField(
                                  key: nameKey,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: "Name",
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context, nameKey.currentState?.value);
                                },
                                icon: const Icon(Icons.add),
                                label: const Text("New"),
                              )
                            ],
                          ),
                        )
                      ],
                    );
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
                      return SimpleDialog(
                        title: const Text("Pick Field"),
                        children: [
                          Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    for (int i = 0; i < builders.length; i++)
                                      if (!(appState.searchValues?.containsKey(builders[i].key) == true))
                                      Card(
                                        elevation: 2,
                                        child: InkWell(
                                          customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
                                          onTap: () {
                                            Navigator.pop(context, builders[i].key);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Icon(builders[i].icon),
                                                Text(builders[i].label)
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.cancel),
                              label: const Text("Cancel"),
                            ),
                          ),
                        ],
                      );
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
                  var teamDataManager = appState.builder?.teamManager;
                  if (teamDataManager != null && appState.searchValues != null) {
                    print(teamDataManager.getRankedTeams(appState.searchValues!));
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