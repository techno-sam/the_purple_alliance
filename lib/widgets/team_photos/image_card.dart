import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:the_purple_alliance/screens/main/scouting_sub/photos/image_details.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/images/image_record.dart';
import 'package:the_purple_alliance/state/images/image_sync_manager.dart';

class ImageCard extends StatefulWidget {
  final String hash;
  const ImageCard(this.hash, {super.key});

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  late Future<File> _imageFuture;
  final GlobalKey<State<FutureBuilder>> _imgKey = GlobalKey<
      State<FutureBuilder>>(debugLabel: "futureImage");
  final GlobalKey<State<FutureBuilder>> _imgKeyInner = GlobalKey<
      State<FutureBuilder>>(debugLabel: "futureImageInner");
  final ScrollController _tagsController = ScrollController();

  @override
  void initState() {
    super.initState();
    _imageFuture = getImageFile(widget.hash, quick: true).then((f) async {
      while (!(await f.exists())) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    var syncManager = appState.imageSyncManager;
    ImageRecord record = syncManager.knownImages.firstWhere((element) =>
    element.uuid == widget.hash);
    String hash = record.uuid;
    bool imageExists = syncManager.downloadedUUIDs.contains(hash);

    var placeholder = Icon(
        Icons.photo_outlined,
        size: 50,
        color: (theme.iconTheme.color ?? Colors.black).withOpacity(
            0.15));
    var heroTag = "photo_${record.uuid}";

    return AspectRatio(
      aspectRatio: 5 / 8,
      child: Card(
          elevation: 3,
          child: InkWell(
            onTap: () {
              if (syncManager.downloadedUUIDs.contains(hash)) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return ImageDetailsPage(heroTag: heroTag,
                          imgKeyInner: _imgKeyInner,
                          imageFuture: _imageFuture,
                          placeholder: placeholder,
                          theme: theme,
                          record: record);
                    }
                ));
              } else {
                syncManager.addToDownloadManual(record);
              }
            },
            customBorder: theme.cardTheme.shape
                ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            //match shape of card
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Hero(
                          tag: "author_label_${record.uuid}",
                          child: Text(
                            "Author: ",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17.0,
                              color: theme.colorScheme.onPrimaryContainer
                            ) ?? TextStyle(
                              fontSize: 17.0,
                              color: theme.colorScheme.onPrimaryContainer
                            )
                          )
                        ),
                        Hero(
                          tag: "author_content_${record.uuid}",
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              record.author,
                              style: TextStyle(
                                fontSize: 16.0,
                                color: theme.colorScheme.onPrimaryContainer
                              )
                            )
                          )
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Hero(
                      tag: heroTag,
                      child: Center(
                        child: (imageExists
                            ? FutureBuilder(key: _imgKey,
                            future: _imageFuture,
                            builder: (context, snapshot) {
                              if (snapshot.data != null) {
                                return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(snapshot.data!)
                                );
                              } else {
                                return placeholder;
                              }
                            })
                            : placeholder),
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(record.tags.isEmpty ? "No Tags" : "Tags:",
                          style: theme.textTheme.titleMedium),
                      if (record.tags.isNotEmpty)
                        const SizedBox(width: 8),
                      if (record.tags.isNotEmpty)
                        Expanded(
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 8),
                                        child: Text(tag,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(fontSize: 16)),
                                      )),
                                  ]
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                ],
              ),
            ),
          )
      ),
    );
  }
}