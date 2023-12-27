import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:the_purple_alliance/main.dart';

class SearchConfigurationSelection extends StatelessWidget {
  const SearchConfigurationSelection({
    super.key,
    required this.appState,
    required this.theme,
    required this.nameKey,
  });

  final MyAppState appState;
  final ThemeData theme;
  final GlobalKey<FormFieldState<String>> nameKey;

  @override
  Widget build(BuildContext context) {
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
              Tooltip(
                message: "New",
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, nameKey.currentState?.value);
                  },
                  icon: const Icon(Icons.add),
                  label: getWindowType(context) >= AdaptiveWindowType.medium ? const Text("New") : const SizedBox(),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}