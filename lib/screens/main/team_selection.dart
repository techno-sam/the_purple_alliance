import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/widgets/display_card.dart';
import 'package:the_purple_alliance/widgets/team_tile.dart';

class TeamSelectionPage extends StatelessWidget {

  const TeamSelectionPage(this._viewTeam, {super.key});

  final void Function() _viewTeam;

  static final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "teamSelection");
  static final GlobalKey<FormFieldState<String>> _entryKey = GlobalKey<FormFieldState<String>>(debugLabel: "teamSelectionEntry");

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    List<int> teams = appState.builder?.teamManager.managers.keys.toList() ?? [];
    teams.sort();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (appState.builder != null)
            Expanded(
              child: GridView.builder(
                itemCount: teams.length,
                itemBuilder: (context, index) => TeamTile(teams[index], _viewTeam),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 128,
                  childAspectRatio: 2.0,
                ),
              ),
            ),
          if (appState.builder != null)
            Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: _formKey,
              child: Card(
                color: oldColors ? theme.colorScheme.primaryContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          key: _entryKey,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            labelText: "Add Team",
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: "",
                          validator: (String? value) {
                            if (value == null) {
                              return "Value must be a number";
                            }
                            var num = int.tryParse(value);
                            if (num == null) {
                              return "Value must be a number";
                            }
                            if (num < 1) {
                              return "Invalid team number";
                            }
                            if (num > 9999) {
                              return "Invalid team number";
                            }
                            if (teams.contains(num)) {
                              return "Already added";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () {
                          if (_formKey.currentState != null && _formKey.currentState!.validate() && _entryKey.currentState != null) {
                            var value = _entryKey.currentState!.value;
                            if (value != null) {
                              var teamNum = int.tryParse(value);
                              if (teamNum != null && !teams.contains(teamNum)) {
                                log('need to confirm team: ${_entryKey.currentState!.value}');
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text("Confirm team"),
                                      content: Text("Do you want to add team $teamNum?\nThis cannot be undone."),
                                      actions: [
                                        TextButton(
                                          child: const Text("Cancel"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _entryKey.currentState!.reset();
                                          },
                                        ),
                                        TextButton(
                                            child: const Text("Continue"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _entryKey.currentState!.reset();
                                              log("Continuing with $teamNum");
                                              appState.builder?.initializeTeam(teamNum);
                                            }
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            }
                          }
                        },
                        tooltip: "Add",
                        icon: const Icon(Icons.add_circle, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (appState.builder == null)
            DisplayCard(text: "Not loaded", icon: Icon(Icons.error_outline, color: !oldColors ? null : theme.colorScheme.onPrimary)),
        ],
      ),
    );
  }
}