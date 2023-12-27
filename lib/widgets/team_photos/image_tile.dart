import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:the_purple_alliance/screens/main/scouting_sub/photos/image_details.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/images/image_record.dart';
import 'package:the_purple_alliance/state/images/image_sync_manager.dart';

class ImageTile extends StatefulWidget {
  final String hash;
  const ImageTile(this.hash, {super.key});

  @override
  State<ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<ImageTile> {

  late Future<File> _imageFuture;
  final GlobalKey<State<FutureBuilder>> _imgKey = GlobalKey<State<FutureBuilder>>(debugLabel: "futureImage");
  final GlobalKey<State<FutureBuilder>> _imgKeyInner = GlobalKey<State<FutureBuilder>>(debugLabel: "futureImageInner");

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
    ImageRecord record = syncManager.knownImages.firstWhere((element) => element.uuid == widget.hash);
    String hash = record.uuid;
    bool imageExists = syncManager.downloadedUUIDs.contains(hash);
    var placeholder = Icon(
        Icons.photo_outlined,
        size: 50,
        color: (theme.iconTheme.color ?? Colors.black).withOpacity(0.15)
    );
    var heroTag = "photo_${record.uuid}";
    return Card(
        child: InkWell(
            onTap: () {
              //log("tapped image ${widget.index}");
              /*setState(() {
                _showImg = !_showImg;
              });*/
              if (syncManager.downloadedUUIDs.contains(hash)) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return ImageDetailsPage(
                          heroTag: heroTag,
                          imgKeyInner: _imgKeyInner,
                          imageFuture: _imageFuture,
                          placeholder: placeholder,
                          theme: theme,
                          record: record
                      );
                    }
                ));
              } else {
                syncManager.addToDownloadManual(record);
              }
            },
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            //match shape of card
            child: Container(
              padding: const EdgeInsets.all(4.0),
              child: Hero(
                tag: heroTag,
                child: Center(
                  child: (imageExists
                      ? FutureBuilder(key: _imgKey, future: _imageFuture, builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(snapshot.data!)
                      );
                    } else {
                      return placeholder;
                    }
                  }) : placeholder),
                ),
              ),
            )
        )
    );
  }
}