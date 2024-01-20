import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/dropdown.dart';

import '../widgets/dropdown_with_other.dart';
import 'abstract_synchronized_builder.dart';

class DropdownWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<DropdownDataValue> {
  DropdownWidgetBuilder.fromJson(super.schemeData) : super.fromJson();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownWithOther(key: Key("${key}_outer"), padding: padding, formKey: key, label: label, dataValue: dataValue, theme: theme);
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return ElevatedButton.icon(
        onPressed: () {
          showDialog(
              context: context, builder: (context) {
            var appState = context.watch<MyAppState>();
            final theme = Theme.of(context);
            return Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: Key("$key search"),
              child: SimpleDialog(
                title: Text("Configuring '$label'"),
                children: [
                  const SizedBox(width: 400),
                  for (String option in dataValue?.options ?? [])
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Text(option),
                            const Spacer(),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                key: Key("$key search points $option"),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText: "Ignored",
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
                                  //print("changed to `$v`");
                                  int? vInt = int.tryParse(v);
                                  if (appState.searchValues != null && appState.searchValues![key] is! Map<String, int>) {
                                    //print("wrong type: ${appState.searchValues[_key]}");
                                    appState.searchValues![key] = {};
                                  }
                                  if (vInt != null) {
                                    //print("vInt: $vInt");
                                    appState.searchValues?[key][option] = vInt;
                                  } else {
                                    //print("null, removing");
                                    //print("before: ${appState.searchValues[_key]}");
                                    appState.searchValues?[key].remove(option);
                                    //print("now: ${appState.searchValues[_key]}");
                                  }
                                },
                                initialValue: "${(appState.searchValues?[key] is Map<String, int> || (appState.searchValues?[key] is Map<String, dynamic> && appState.searchValues?[key][option] is int)) ? (appState.searchValues?[key][option] ?? "") : ""}",
                              ),
                            ),
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
              ),
            );
          });
        },
        icon: const Icon(Icons.settings),
        label: const Text("Configure")
    );
  }

  @override
  IconData get icon => Icons.arrow_drop_down_circle_outlined;
}