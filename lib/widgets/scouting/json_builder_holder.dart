import 'package:flutter/material.dart';
import 'package:the_purple_alliance/widgets/scouting/builders/abstract_builder.dart';

/// So that individual widgets can update independently, hopefully increasing performance
class JsonBuilderHolder extends StatelessWidget {
  final JsonWidgetBuilder builder;

  const JsonBuilderHolder({super.key, required this.builder});
  
  @override
  Widget build(BuildContext context) {
    return builder.build(context);
  }
}