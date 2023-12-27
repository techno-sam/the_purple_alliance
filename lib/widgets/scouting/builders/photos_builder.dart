import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/screens/main/scouting_sub/photos/team_photo_page.dart';

import 'abstract_builder.dart';

class PhotosBuilder extends JsonWidgetBuilder {
  late final String _label;
  double? _padding;

  PhotosBuilder.fromJson(Map<String, dynamic> schemeData) : super.fromJson(schemeData) {
    _label = schemeData["label"];
    if (schemeData.containsKey("padding")) {
      var padding = schemeData["padding"];
      if (padding is double) {
        _padding = padding;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    var heroTag = "photos_$_label";
    return Padding(
      padding: EdgeInsets.all(_padding ?? 8.0),
      child: Card(
          color: oldColors ? theme.colorScheme.primaryContainer : null,
          child: Container(
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Hero(tag: heroTag, child: Text(_label, style: theme.textTheme.headlineSmall)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () {
                      appState.imageSyncManager.addToDownload(appState.imageSyncManager.notDownloaded);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: ((context) {
                                return PhotosPage(heroTag, _label, appState.builder?.currentTeam ?? 0);
                              })
                          )
                      );
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text("View Photos"),
                  ),
                ],
              )
          )
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return const SizedBox();
  }

  @override
  IconData get icon => Icons.photo_camera_back_outlined;

  @override
  String get label => _label;
}