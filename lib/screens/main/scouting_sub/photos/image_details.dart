import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:the_purple_alliance/state/images/image_record.dart';
import 'package:the_purple_alliance/state/images/image_sync_manager.dart';

import 'team_photo_page.dart';

class ImageDetailsPage extends StatelessWidget {
  ImageDetailsPage({
    super.key,
    required this.heroTag,
    required GlobalKey<State<FutureBuilder>> imgKeyInner,
    required Future<File> imageFuture,
    required this.placeholder,
    required this.theme,
    required this.record,
  }) : _imgKeyInner = imgKeyInner, _imageFuture = imageFuture;

  final String heroTag;
  final GlobalKey<State<FutureBuilder>> _imgKeyInner;
  final Future<File> _imageFuture;
  final Icon placeholder;
  final ThemeData theme;
  final ImageRecord record;
  final ScrollController _tagsController = ScrollController();

  @override
  Widget build(BuildContext context) {
    ImageSyncManager syncManager = context.watch<ImageSyncManager>();
    return Scaffold(
        appBar: AppBar(
          title: const Text("Back"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: 3,
                child: Hero(
                  tag: heroTag,
                  child: Center(
                    child: FutureBuilder(
                        key: _imgKeyInner,
                        future: _imageFuture,
                        builder: (context, snapshot) {
                          if (snapshot.data != null) {
                            return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  snapshot.data!,
                                )
                            );
                          } else {
                            return placeholder;
                          }
                        }
                    ),
                  ),
                ),
              ),
              const Divider(indent: 8, endIndent: 8,),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Hero(tag: "author_label_${record.uuid}", child: Text("Author: ", style: theme.textTheme.titleMedium)),
                  Hero(tag: "author_content_${record.uuid}", child: Material(color: Colors.transparent, child: Text(record.author))),
                  const SizedBox(height: 30, child: VerticalDivider(indent: 8, thickness: 1, width: 16, color: Colors.grey,)),
                  Expanded(
                    flex: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(record.tags.isEmpty ? "No Tags" : "Tags:", style: theme.textTheme.titleMedium),
                        if (record.tags.isNotEmpty)
                          const SizedBox(width: 8),
                        if (record.tags.isNotEmpty)
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: extendedScrollableTypes),
                              child: Scrollbar(
                                controller: _tagsController,
                                scrollbarOrientation: ScrollbarOrientation.bottom,
                                child: SingleChildScrollView(
                                  controller: _tagsController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                      children: [
                                        for (String tag in record.tags)
                                          Card(child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                            child: Text(tag, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
                                          )),
                                      ]
                                  ),
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: syncManager.isKnown(record.uuid) ? null : FloatingActionButton(
          child: const Icon(Icons.upload),
          onPressed: () async {
            await syncManager.remindUpload(record.uuid);
          },
        )
    );
  }
}