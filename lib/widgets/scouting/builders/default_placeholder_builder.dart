import 'package:flutter/material.dart';

import 'abstract_builder.dart';

class DefaultPlaceholderBuilder extends JsonWidgetBuilder {
  final String type;
  DefaultPlaceholderBuilder.fromJson(super.schemeData, this.type) : super.fromJson();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.red.shade900,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.amber),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.amber)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return const SizedBox();
  }

  @override
  IconData get icon => Icons.error_outline;

  @override
  String get label => "Undefined widget type '$type', contact your developer to fix the scouting scheme.";
}