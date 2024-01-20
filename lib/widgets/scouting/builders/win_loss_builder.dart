import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/win_loss.dart';

import 'abstract_synchronized_builder.dart';

class WinLossBuilder extends SynchronizedBuilder<WinLossDataValue> {
  double? _padding;

  WinLossBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
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
      child: Card(
        color: oldColors ? theme.colorScheme.primaryContainer : null,
        child: Container(
          margin: const EdgeInsets.all(4.0),
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.headlineSmall),
              const Divider(),
              Consumer<MyAppState>(
                  builder: (context, appState, child) {
                    return Row(
                      children: [
                        if (getWindowType(context) >= AdaptiveWindowType.medium)
                          const Spacer(flex: 4),
                        Expanded(
                          child: Card(
                            color: Colors.greenAccent,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                children: [
                                  const Text("Wins"),
                                  Text(dataValue?.wins.toString() ?? "0"),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            color: Colors.redAccent,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                children: [
                                  const Text("Losses"),
                                  Text(dataValue?.losses.toString() ?? "0"),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            color: Colors.amberAccent,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                children: [
                                  const Text("Ties"),
                                  Text(dataValue?.ties.toString() ?? "0"),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (getWindowType(context) >= AdaptiveWindowType.medium)
                          const Spacer(flex: 4),
                      ],
                    );
                  }
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(context: context, builder: (context) {
          final appState = context.watch<MyAppState>();
          final theme = Theme.of(context);
          return Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            key: Key("$key search"),
            child: SimpleDialog(
              title: Text("Configuring '$label'"),
              children: [
                const SizedBox(width: 400),
                for (WinLossSearchOption option in WinLossSearchOption.values)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Text(option.searchLabel),
                        const Spacer(),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            key: Key("$key search points ${option.searchKey}"),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: "0",
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v == "") {
                                return null;
                              }
                              if (int.tryParse(v) == null) {
                                return "Must be a number";
                              }
                              return null;
                            },
                            onChanged: (v) {
                              int vInt = int.tryParse(v) ?? 0;
                              if (appState.searchValues != null && appState.searchValues![key] is! Map) {
                                appState.searchValues![key] = {};
                              }
                              appState.searchValues?[key][option.searchKey] = vInt;
                            },
                            initialValue: "${(appState.searchValues?[key] is Map<String, int> || (appState.searchValues?[key] is Map<String, dynamic> && appState.searchValues?[key][option.searchKey] is int)) ? (appState.searchValues?[key][option.searchKey] ?? "") : ""}",
                          )
                        )
                      ],
                    )
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Done")
                    ),
                  ],
                )
              ],
            )
          );
        });
      },
      icon: const Icon(Icons.settings),
      label: const Text("Configure")
    );
  }

  @override
  IconData get icon => Icons.scoreboard_outlined;

  @override
  String get label => "Match Records";
}