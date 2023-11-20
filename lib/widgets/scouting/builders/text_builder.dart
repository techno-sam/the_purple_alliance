import 'package:flutter/material.dart';

import 'abstract_builder.dart';

enum TextType {
  standard,
  heading
}

class TextWidgetBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;
  String? _style;

  TextType get style => _style == null ? TextType.standard : (TextType.values.firstWhere((element) => element.name == _style, orElse: () => TextType.standard));

  TextWidgetBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
    if (schemeData.containsKey("style")) {
      _style = schemeData["style"];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    switch (style) {
      case TextType.heading:
        child = Column(
          children: [
            Divider(
              color: Colors.grey.shade700,
              thickness: 0.5,
              indent: 25,
              endIndent: 25,
            ),
            Text(_label, style: theme.textTheme.titleLarge),
            const Divider(color: Colors.black),
          ],
        );
        break;
      default:
        child = Text(_label);
        break;
    }
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: child,
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return const SizedBox();
  }

  @override
  IconData get icon => Icons.text_fields;

  @override
  String get label => _label;
}