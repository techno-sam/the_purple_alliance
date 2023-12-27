import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/star_rating.dart';

import '../widgets/star_rating.dart';
import 'abstract_synchronized_builder.dart';

class StarRatingWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<StarRatingDataValue> {
  StarRatingWidgetBuilder.fromJson(super.schemeData) : super.fromJson();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 2),
              StarRating(
                key: Key("$key:rating_${dataValue?.personalValue}"),
                initialRating: dataValue?.personalValue ?? 0,
                averageRating: dataValue?.single == true ? null : dataValue?.averageValue,
                onChanged: (value) {
                  dataValue?.personalValue = value;
                },
                color: Colors.amber,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: Key("$key search"),
      child: SizedBox(
        width: 200,
        child: TextFormField(
          key: Key("$key search text"),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: const UnderlineInputBorder(),
            labelText: "Point Value",
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
            if (v == "") {
              v = "0";
            }
            int? vInt = int.tryParse(v);
            if (vInt != null) {
              appState.searchValues?[key] = vInt;
            }
          },
          initialValue: "${appState.searchValues?[key] ?? 0}",
        ),
      ),
    );
  }

  @override
  IconData get icon => Icons.star_border;
}