import 'package:flutter/material.dart';

abstract class JsonWidgetBuilder {
  JsonWidgetBuilder.fromJson(Map<String, dynamic> schemeData);
  Widget build(BuildContext context);
  Widget buildSearchEditor(BuildContext context);
  IconData get icon;
  String get label;
}