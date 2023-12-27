import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/text.dart';

import 'abstract_synchronized_builder.dart';

class TextFieldWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<TextDataValue> {

  late final TextEditingController _controller;
  TextFieldWidgetBuilder.fromJson(super.schemeData) : super.fromJson() {
    _controller = TextEditingController(text: dataValue?.value ?? TextDataValue.getDefault());
  }

  @override
  Widget build(BuildContext context) {
    _controller.text = dataValue?.value ?? TextDataValue.getDefault();
    return Padding(
      padding: EdgeInsets.all(padding ?? 8.0),
      child: Consumer<MyAppState>(
          builder: (context, appState, child) {
            return TextFormField(
              key: Key(key),
              decoration: InputDecoration(
                border: const UnderlineInputBorder(),
                labelText: label,
              ),
              controller: _controller,
//            initialValue: _dataValue?.value ?? TextDataValue.getDefault(),
              onChanged: (value) {
                dataValue?.value = value;
              },
            );
          }
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return const SizedBox();
  }

  @override
  IconData get icon => Icons.short_text;
}