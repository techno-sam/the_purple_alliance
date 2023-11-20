import 'package:flutter/material.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/abstract_data_value.dart';
import 'package:the_purple_alliance/widgets/scouting/builders/abstract_synchronized_builder.dart';

class SearchFieldPickerDialog extends StatelessWidget {
  const SearchFieldPickerDialog({
    super.key,
    required this.builders,
    required this.appState,
    required this.theme,
  });

  final List<SynchronizedBuilder<DataValue>> builders;
  final MyAppState appState;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
}