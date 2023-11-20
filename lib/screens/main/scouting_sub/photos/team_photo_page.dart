import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:camera/camera.dart';
import 'package:the_purple_alliance/screens/main/scouting_sub/photos/photo_meta.dart';
import 'package:the_purple_alliance/screens/main/scouting_sub/photos/take_photo.dart';

import 'package:the_purple_alliance/utils/util.dart';
import 'package:the_purple_alliance/state/data_manager.dart';
import 'package:the_purple_alliance/widgets/team_photos/camera_card.dart';
import 'package:the_purple_alliance/widgets/team_photos/camera_tile.dart';
import 'package:the_purple_alliance/widgets/team_photos/image_card.dart';
import 'package:the_purple_alliance/widgets/team_photos/image_tile.dart';


const Set<PointerDeviceKind> extendedScrollableTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  // The VoiceAccess sends pointer events with unknown type when scrolling
  // scrollables.
  PointerDeviceKind.unknown,
  PointerDeviceKind.mouse,
};

class PhotosPage extends StatefulWidget {
  final String heroTag;
  final String label;
  final int teamNumber;

  const PhotosPage(this.heroTag, this.label, this.teamNumber, {super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  late CameraDescription _cameraDescription;
  final Map<String, GlobalKey<State<ImageTile>>> _gridKeys = {};
  final Map<String, GlobalKey<State<ImageCard>>> _listKeys = {};

  final ScrollController _imagesController = ScrollController();

  @override
  void initState() {
    super.initState();
    availableCameras().then((cameras) {
      final camera = cameras
          .toList()
          .first;
      setState(() {
        _cameraDescription = camera;
      });
      log("Setup camera");
    }).catchError((err) {
      log("$err");
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    cameraHandler(ImageSyncManager imageSyncManager) async {
      var navigator = Navigator.of(context);
      final String? imagePath = await navigator.push(MaterialPageRoute(
        builder: (_) =>
        isCameraSupported()
            ? TakePhoto(camera: _cameraDescription)
            : const TakePhotoFake(),
      ));
      log("imagePath: $imagePath");
      if (imagePath != null) {
        final ImageRecord? imageRecord = await navigator.push(MaterialPageRoute(
            builder: (_) => PhotoMetaPage(imagePath: imagePath,
                teamNumber: widget.teamNumber)
        ));
        log("Record: $imageRecord");
        if (imageRecord != null) {
          imageSyncManager.addTakenPicture(
              imageRecord.team, imageRecord.author, imageRecord.tags,
              imagePath);
        }
      }
    }
    return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.primaryColorDark,
          title: Hero(tag: widget.heroTag, child: Text(widget.label, style: theme.textTheme.headlineSmall)),
          centerTitle: true,
        ),
        body: Center(
          child: Consumer<ImageSyncManager>(
            builder: (context, imageSyncManager, child) => appState.gridMode ? GridView.builder(
              itemCount: imageSyncManager.knownImages.where((record) => record.team == widget.teamNumber).length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 100,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                String? hash = index == 0 ? null : appState.imageSyncManager.knownImages.where((record) => record.team == widget.teamNumber).elementAt(index - 1).uuid;
                return index == 0 ? CameraTile(() async => await cameraHandler(imageSyncManager)) : ImageTile(
                    hash!,
                    key: _gridKeys.putIfAbsent(hash, () => GlobalKey<State<ImageTile>>(debugLabel: "imageTile$hash"))
                );
              },
            ) : ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: extendedScrollableTypes),
              child: Scrollbar(
                controller: _imagesController,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: ListView.builder(
                    controller: _imagesController,
                    scrollDirection: Axis.horizontal,
                    itemCount: imageSyncManager.knownImages.where((record) => record.team == widget.teamNumber).length + 1,
                    prototypeItem: const AspectRatio(aspectRatio: 5/8),
                    itemBuilder: (context, index) {
                      String? hash = index ==0 ? null : appState.imageSyncManager.knownImages.where((record) => record.team == widget.teamNumber).elementAt(index - 1).uuid;
                      return index == 0 ? CameraCard(() async => await cameraHandler(imageSyncManager)) : ImageCard(hash!, key: _listKeys.putIfAbsent(hash, () => GlobalKey<State<ImageCard>>(debugLabel: "ImageCard$hash")));
                    }
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              appState.gridMode = !appState.gridMode;
            });
          },
          child: Icon(appState.gridMode ? Icons.grid_view : Icons.list),
        )
    );
  }
}