import 'dart:developer';
import 'dart:math' as math;
import 'dart:io';

import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:adaptive_navigation/adaptive_navigation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:camera/camera.dart';
import 'package:the_purple_alliance/util.dart';
import 'package:file_picker/file_picker.dart';

import 'data_manager.dart';

const Set<PointerDeviceKind> _extendedScrollableTypes = <PointerDeviceKind>{
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
      //.where((camera) => camera.lensDirection == CameraLensDirection.back)
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
            builder: (_) => PhotoMeta(imagePath: imagePath,
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
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: _extendedScrollableTypes),
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
                /*children: [
                  CameraCard(() async => await cameraHandler(imageSyncManager)),
                ],*/
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

class CameraCard extends StatelessWidget {
  final void Function() onTap;
  const CameraCard(this.onTap, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 5/8,
      child: Card(
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
              child: Column(
//              mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Attach Picture',
                    style: TextStyle(fontSize: 17.0, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: theme.primaryColorDark,//Colors.indigo.shade400,
                        size: 128,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
      ),
    );
  }
}

class CameraTile extends StatelessWidget {
  final Function() onTap;
  const CameraTile(this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        child: InkWell(
            onTap: onTap,
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
            child: const Icon(Icons.photo_camera_outlined, size: 48,)
        )
    );
  }
}

class ImageCard extends StatefulWidget {
  final String hash;
  const ImageCard(this.hash, {super.key});

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  late Future<File> _imageFuture;
  final GlobalKey<State<FutureBuilder>> _imgKey = GlobalKey<State<FutureBuilder>>(debugLabel: "futureImage");
  final GlobalKey<State<FutureBuilder>> _imgKeyInner = GlobalKey<State<FutureBuilder>>(debugLabel: "futureImageInner");
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
    ImageRecord record = syncManager.knownImages.firstWhere((element) => element.uuid == widget.hash);
    String hash = record.uuid;
    bool imageExists = syncManager.downloadedUUIDs.contains(hash);

    var placeholder = Icon(
        Icons.photo_outlined,
        size: 50,
        color: (theme.iconTheme.color ?? Colors.black).withOpacity(
            0.15));
    var heroTag = "photo_${record.uuid}";

    return AspectRatio(
      aspectRatio: 5/8,
      child: Card(
          elevation: 3,
          child: InkWell(
            onTap: () {
              //log("tapped image ${widget.index}");
              /*setState(() {
                _showImg = !_showImg;
              });*/
              if (syncManager.downloadedUUIDs.contains(hash)) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return ImageDetailsPage(heroTag: heroTag, imgKeyInner: _imgKeyInner, imageFuture: _imageFuture, placeholder: placeholder, theme: theme, record: record);
                    }
                ));
              } else {
                syncManager.addToDownloadManual(record);
              }
            },
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
              child: Column(
                children: [
                  /*Text(
                    'Author: ${record.author}',
                    style: TextStyle(fontSize: 17.0, color: theme.colorScheme.onPrimaryContainer),
                  ),
                   */
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Hero(tag: "author_label_${record.uuid}", child: Text("Author: ", style: theme.textTheme.titleMedium?.copyWith(fontSize: 17.0, color: theme.colorScheme.onPrimaryContainer) ?? TextStyle(fontSize: 17.0, color: theme.colorScheme.onPrimaryContainer))),
                        Hero(tag: "author_content_${record.uuid}", child: Material(color: Colors.transparent, child: Text(record.author, style: TextStyle(fontSize: 16.0, color: theme.colorScheme.onPrimaryContainer)))),
                      ],
                    ),
                  ),
                  Expanded(
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
                        })// Image.network('https://picsum.photos/250?image=${widget.index}')
                            : placeholder),
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(record.tags.isEmpty ? "No Tags" : "Tags:", style: theme.textTheme.titleMedium),
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
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                        child: Text(tag, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
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
    /*Future<File> imageFuture = syncManager.getImageFile(hash, quick: true).then((f) async {
      while (!(await f.exists())) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return f;
    });*/
    var placeholder = Icon(
        Icons.photo_outlined,
        size: 50,
        color: (theme.iconTheme.color ?? Colors.black).withOpacity(
            0.15));
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
                    return ImageDetailsPage(heroTag: heroTag, imgKeyInner: _imgKeyInner, imageFuture: _imageFuture, placeholder: placeholder, theme: theme, record: record);
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
                })// Image.network('https://picsum.photos/250?image=${widget.index}')
                    : placeholder),
                ),
              ),
            )
        )
    );
  }
}

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
//                                const SizedBox(width: 30),
                const SizedBox(height: 30, child: VerticalDivider(indent: 8, thickness: 1, width: 16, color: Colors.grey,)),
////                                const Spacer(flex: 2),
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
                            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: _extendedScrollableTypes),
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
////                                const Spacer(),
              ],
            ),
//                            Spacer(),
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

class CardPicture extends StatelessWidget {
  const CardPicture({super.key, this.onTap, this.imagePath});

  final Function()? onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (imagePath != null) {
      return Card(
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(10.0),
          width: size.width * .70,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(4.0)),
            image: DecorationImage(
                fit: BoxFit.cover, image: FileImage(File(imagePath as String))),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(3.0, 3.0),
                        blurRadius: 2.0,
                      )
                    ]
                ),
                child: IconButton(onPressed: (){
                  log('icon press');
                }, icon: const Icon(Icons.delete, color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Card(
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
            width: size.width * .70,
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach Picture',
                  style: TextStyle(fontSize: 17.0, color: Colors.grey[600]),
                ),
                Icon(
                  Icons.photo_camera,
                  color: Colors.indigo[400],
                )
              ],
            ),
          ),
        ));
  }
}

class PhotoMeta extends StatelessWidget {
  final String imagePath;
  final int teamNumber;
  PhotoMeta({super.key, required this.imagePath, required this.teamNumber});
  final GlobalKey<_TagSelectionState> _tagSelectionKey = GlobalKey<_TagSelectionState>(debugLabel: "tagSelectionKey");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Image metadata"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Text("Team $teamNumber", style: theme.textTheme.headlineMedium),
                Image.file(
                  File(imagePath),
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    return Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(indent: 5, endIndent: 5, height: 20),
                TagSelection(key: _tagSelectionKey),
                const Divider(indent: 5, endIndent: 5, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_a_photo, color: Colors.black),
                      label: const Text("Post", style: TextStyle(color: Colors.black)),
                      onPressed: () {
                        //print("making record: $tagSelectionKey; ${tagSelectionKey.currentState}; ${tagSelectionKey.currentState?.tags}");
                        ImageRecord record = ImageRecord("", appState.username, _tagSelectionKey.currentState?.tags ?? [], teamNumber);
                        Navigator.of(context).pop(record);
                      },
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.green))
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.black),
                      label: const Text("Cancel", style: TextStyle(color: Colors.black)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red))
                    ),
                  ]
                )
              ]
            ),
          ),
        ),
      )
    );
  }
}

class TagSelection extends StatefulWidget {
  const TagSelection({
    super.key,
  });

  @override
  State<TagSelection> createState() => _TagSelectionState();
}

class _TagSelectionState extends State<TagSelection> {
  List<String> tags = [];
  final GlobalKey<FormFieldState<String>> _tagKey = GlobalKey<FormFieldState<String>>(debugLabel: "tag");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text("Tags", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (String tag in tags)
                  Card(child: InkWell(
                    onTap: () {
                      setState(() {
                        tags.remove(tag);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: Text(tag, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
                    ),
                  )),
            ]
            ),
          ),
        ),
//        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              String? tag = await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Add tag"),
                    content: TextFormField(
                      key: _tagKey,
                      decoration: const InputDecoration(
                        hintText: "Enter tag",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(_tagKey.currentState?.value);
                        },
                        child: const Text("Add"),
                      ),
                    ],
                  );
                },
              );
              log("tag: $tag");
              if (tag != null && tag != "") {
                setState(() {
                  if (!tags.contains(tag)) {
                    tags.add(tag);
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }
}

class TakePhotoFake extends StatelessWidget {
  const TakePhotoFake({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select picture'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            //print("pick");
            var navigator = Navigator.of(context);
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              dialogTitle: "Image file",
              type: FileType.image,
              lockParentWindow: true,
            );
            //print('result: ${result?.files.single}');
            if (result?.files.single.path != null) {
              navigator.pop(result?.files.single.path);
            }
          },
          child: const Text("Pick"),
        ),
      ),
    );
  }
}

class TakePhoto extends StatefulWidget {
  final CameraDescription? camera;

  const TakePhoto({super.key, this.camera});

  @override
  State<TakePhoto> createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera as CameraDescription,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  Future<XFile?> takePicture() async {
    if (_controller.value.isTakingPicture) {
      return null;
    }

    try {
      XFile file = await _controller.takePicture();
      return file;
    } on CameraException catch (e) {
      log("$e");
      return null;
    }
  }


  @override
  void dispose() async {
    super.dispose();
    await _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take picture'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var nav = Navigator.of(context);
          final file = await takePicture();
          nav.pop(file?.path);
        },
        child: const Icon(Icons.camera_alt),
      ),

      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        }
      )
    );
  }
}

class CommentList extends StatelessWidget {
  const CommentList({
    super.key,
    required this.theme,
    required this.comments,
  });

  final ThemeData theme;
  final Map<String, String> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.primaryColorDark,
      child: Column(
        children: [
          const Divider(color: Colors.black, indent: 20, endIndent: 20,),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  for (MapEntry<String, String> comment in comments.entries)
                    if (comment.value != '')
                      SizedBox(
                        height: 200,
  //                      aspectRatio: _isLargeScreen(context) ? 4 : _isMediumScreen(context) ? 3 : 2,
                        child: Card(
                          color: theme.primaryColorLight,
                          elevation: 2,
                          child: Container(
                            margin: const EdgeInsets.all(4.0),
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.key, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
                                Divider(color: theme.colorScheme.onSurface, endIndent: 50),
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      child: Text(
                                        comment.value,
                                        style: TextStyle(color: theme.colorScheme.onSurface)
                                      )
                                    )
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StarRating extends StatefulWidget {
  const StarRating({
    super.key,
    required this.initialRating,
    required this.averageRating,
    this.onChanged,
    this.starCount = 5,
    this.starSize = 20.0,
    this.interactable = true,
    this.color,
  });

  final double initialRating;
  final double? averageRating;
  final Function(double)? onChanged;
  final int starCount;
  final double starSize;
  final bool interactable;
  final Color? color;

  @override
  State<StarRating> createState() => _StarRatingState();
}

double roundDouble(double value, int places){
  num mod = math.pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}

class _StarRatingState extends State<StarRating> {
  double _rating = 0.0;

  _StarRatingState();


  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  Widget buildStar(BuildContext context, int index) {
    Icon icon;
    if (index >= _rating) {
      icon = const Icon(Icons.star_border);
    } else if (index > _rating - 1 && index < _rating) {
      icon = Icon(
        Icons.star_half,
        color: widget.color,
      );
    } else {
      icon = Icon(
        Icons.star,
        color: widget.color,
      );
    }
    return InkResponse(
      onTap: widget.interactable ? () {
        if (widget.onChanged != null) {
          widget.onChanged!(index + 1.0);
        }
        setState(() {
          _rating = index + 1.0;
        });
      } : null,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.starCount; i++)
          buildStar(context, i),
        if (widget.averageRating != null)
          const SizedBox(width: 4),
        if (widget.averageRating != null)
          Text("Avg: ${roundDouble(widget.averageRating ?? 0, 2)}/${widget.starCount+0.0}"),
      ],
    );
  }
}

class DisplayCard extends StatelessWidget {
  const DisplayCard({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall!.copyWith(
      color: !oldColors ? null : theme.colorScheme.onPrimary,
    );

    return Card(
      color: !oldColors ? null : theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Center(child: icon),
            if (icon != null) const SizedBox(width: 8),
            Text(
              text,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

class TappableDisplayCard extends StatelessWidget {
  const TappableDisplayCard({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
  });

  final String text;
  final Function() onTap;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall!.copyWith(
      color: oldColors ? theme.colorScheme.onPrimary : null,
    );

    var splashColorInvert = theme.colorScheme.primary;

    return Card(
      color: oldColors ? theme.colorScheme.primary : null,
      child: InkWell(
        onTap: () async {
          var ret = onTap();
          if (ret is Future) {
            await ret;
          }
        },
        splashColor: Color.fromARGB(255, 255 - splashColorInvert.red, 255 - splashColorInvert.green, 255 - splashColorInvert.blue),
        customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Center(child: icon),
              if (icon != null) const SizedBox(width: 8),
              Text(
                text,
                style: style,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SyncInterval {
  t_1(description: "1 minute", interval: 1),
  t_5(description: "5 minutes", interval: 5),
  t_10(description: "10 minutes", interval: 10),
  t_20(description: "20 minutes", interval: 20),
  manual(description: "Manual")
  ;
  final String description;
  final int? interval;

  const SyncInterval({required this.description, this.interval});

  static SyncInterval fromName(String name) {
    return SyncInterval.values.firstWhere((element) => element.name == name, orElse: () => SyncInterval.manual);
  }
}

class SyncTimeSelector extends StatelessWidget {
  const SyncTimeSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var dropdownTextColor = theme.colorScheme.onPrimaryContainer;
    var appState = context.watch<MyAppState>();
    TextStyle style = TextStyle(
      color: dropdownTextColor,
    );
    return DropdownButtonFormField(
      items: [
        for (SyncInterval interval in SyncInterval.values)
          DropdownMenuItem(
              value: interval,
              child: Row(
                children: [
                  Icon(
                    interval.interval != null ? Icons.timer_outlined : Icons.timer_off_outlined,
                    color: dropdownTextColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                      interval.description,
                      style: style
                  ),
                ],
              )
          ),
      ],
      onChanged: (value) {
        if (value is SyncInterval) {
          appState.syncInterval = value;
        } else {
          appState.syncInterval = SyncInterval.manual;
        }
      },
      dropdownColor: theme.colorScheme.primaryContainer,
      value: appState.syncInterval,
    );
  }
}

enum ImageSyncMode {
  all(description: "All Images", icon: Icons.cloud_sync),
  selected(description: "Selected Team", icon: Icons.sync_problem),
  manual(description: "Manual", icon: Icons.sync_disabled)
  ;
  final String description;
  final IconData icon;

  const ImageSyncMode({required this.description, required this.icon});

  static ImageSyncMode fromName(String name) {
    return ImageSyncMode.values.firstWhere((element) => element.name == name, orElse: () => ImageSyncMode.manual);
  }
}

class ImageSyncSelector extends StatelessWidget {
  const ImageSyncSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var dropdownTextColor = theme.colorScheme.onPrimaryContainer;
    var appState = context.watch<MyAppState>();
    TextStyle style = TextStyle(
      color: dropdownTextColor,
    );
    return DropdownButtonFormField(
      items: [
        for (ImageSyncMode mode in ImageSyncMode.values)
          DropdownMenuItem(
              value: mode,
              child: Row(
                children: [
                  Icon(
                      mode.icon,
                      color: dropdownTextColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                      mode.description,
                      style: style
                  ),
                ],
              )
          ),
      ],
      onChanged: (value) {
        if (value is ImageSyncMode) {
          appState.imageSyncMode = value;
        } else {
          appState.imageSyncMode = ImageSyncMode.manual;
        }
      },
      dropdownColor: theme.colorScheme.primaryContainer,
      value: appState.imageSyncMode,
    );
  }
}

class ColorAdaptiveNavigationScaffold extends StatelessWidget {
  const ColorAdaptiveNavigationScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.endDrawer,
    this.bottomSheet,
    this.backgroundColor,
    this.navigationBackgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.drawerDragStartBehavior = DragStartBehavior.start,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
    this.navigationTypeResolver,
    this.drawerHeader,
    this.drawerFooter,
    this.fabInRail = true,
    this.includeBaseDestinationsInMenu = true,
    this.bottomNavigationOverflow = 5,
  }) : super(key: key);

  /// See [Scaffold.appBar].
  final PreferredSizeWidget? appBar;

  /// See [Scaffold.body].
  final Widget body;

  /// See [Scaffold.floatingActionButton].
  final Widget? floatingActionButton;

  /// See [Scaffold.floatingActionButtonLocation].
  ///
  /// Ignored if [fabInRail] is true.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// See [Scaffold.floatingActionButtonAnimator].
  ///
  /// Ignored if [fabInRail] is true.
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;

  /// See [Scaffold.persistentFooterButtons].
  final List<Widget>? persistentFooterButtons;

  /// See [Scaffold.endDrawer].
  final Widget? endDrawer;

  /// See [Scaffold.drawerScrimColor].
  final Color? drawerScrimColor;

  /// See [Scaffold.backgroundColor].
  final Color? backgroundColor;

  /// See [NavigationRail.backgroundColor].
  final Color? navigationBackgroundColor;

  /// See [Scaffold.bottomSheet].
  final Widget? bottomSheet;

  /// See [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  /// See [Scaffold.primary].
  final bool primary;

  /// See [Scaffold.drawerDragStartBehavior].
  final DragStartBehavior drawerDragStartBehavior;

  /// See [Scaffold.extendBody].
  final bool extendBody;

  /// See [Scaffold.extendBodyBehindAppBar].
  final bool extendBodyBehindAppBar;

  /// See [Scaffold.drawerEdgeDragWidth].
  final double? drawerEdgeDragWidth;

  /// See [Scaffold.drawerEnableOpenDragGesture].
  final bool drawerEnableOpenDragGesture;

  /// See [Scaffold.endDrawerEnableOpenDragGesture].
  final bool endDrawerEnableOpenDragGesture;

  /// The index into [destinations] for the current selected
  /// [AdaptiveScaffoldDestination].
  final int selectedIndex;

  /// Defines the appearance of the items that are arrayed within the
  /// navigation.
  ///
  /// The value must be a list of two or more [AdaptiveScaffoldDestination]
  /// values.
  final List<AdaptiveScaffoldDestination> destinations;

  /// Called when one of the [destinations] is selected.
  ///
  /// The stateful widget that creates the adaptive scaffold needs to keep
  /// track of the index of the selected [AdaptiveScaffoldDestination] and call
  /// `setState` to rebuild the adaptive scaffold with the new [selectedIndex].
  final ValueChanged<int>? onDestinationSelected;

  /// Determines the navigation type that the scaffold uses.
  final NavigationTypeResolver? navigationTypeResolver;

  /// The leading item in the drawer when the navigation has a drawer.
  ///
  /// If null, then there is no header.
  final Widget? drawerHeader;

  /// The footer item in the drawer when the navigation has a drawer.
  ///
  /// If null, then there is no footer.
  final Widget? drawerFooter;

  /// Whether the [floatingActionButton] is inside or the rail or in the regular
  /// spot.
  ///
  /// If true, then [floatingActionButtonLocation] and
  /// [floatingActionButtonAnimation] are ignored.
  final bool fabInRail;

  /// Weather the overflow menu defaults to include overflow destinations and
  /// the overflow destinations.
  final bool includeBaseDestinationsInMenu;

  /// Maximum number of items to display in [bottomNavigationBar]
  final int bottomNavigationOverflow;

  NavigationType _defaultNavigationTypeResolver(BuildContext context) {
    if (_isLargeScreen(context)) {
      return NavigationType.permanentDrawer;
    } else if (_isMediumScreen(context)) {
      return NavigationType.rail;
    } else {
      return NavigationType.bottom;
    }
  }

  Drawer _defaultDrawer(List<AdaptiveScaffoldDestination> destinations) {
    return Drawer(
      backgroundColor: navigationBackgroundColor,
      child: ListView(
        children: [
          if (drawerHeader != null) drawerHeader!,
          for (int i = 0; i < destinations.length; i++)
            ListTile(
              leading: Icon(destinations[i].icon),
              title: Text(destinations[i].title),
              onTap: () {
                onDestinationSelected?.call(i);
              },
            ),
          const Spacer(),
          if (drawerFooter != null) drawerFooter!,
        ],
      ),
    );
  }

  Widget _buildBottomNavigationScaffold() {
    final bottomDestinations = destinations.sublist(
      0,
      math.min(destinations.length, bottomNavigationOverflow),
    );
    final drawerDestinations = destinations.length > bottomNavigationOverflow
        ? destinations.sublist(
        includeBaseDestinationsInMenu ? 0 : bottomNavigationOverflow)
        : <AdaptiveScaffoldDestination>[];
    return Scaffold(
      key: key,
      body: body,
      appBar: appBar,
      drawer: drawerDestinations.isEmpty
          ? null
          : _defaultDrawer(drawerDestinations),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: navigationBackgroundColor,
        items: [
          for (final destination in bottomDestinations)
            BottomNavigationBarItem(
              icon: Icon(destination.icon),
              label: destination.title,
            ),
        ],
        selectedItemColor: navigationBackgroundColor == null ? null : Colors.grey.shade200,
        currentIndex: selectedIndex,
        onTap: onDestinationSelected ?? (_) {},
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavigationRailScaffold() {
    const int railDestinationsOverflow = 7;
    final railDestinations = destinations.sublist(
      0,
      math.min(destinations.length, railDestinationsOverflow),
    );
    final drawerDestinations = destinations.length > railDestinationsOverflow
        ? destinations.sublist(
        includeBaseDestinationsInMenu ? 0 : railDestinationsOverflow)
        : <AdaptiveScaffoldDestination>[];
    return Scaffold(
      key: key,
      appBar: appBar,
      drawer: drawerDestinations.isEmpty
          ? null
          : _defaultDrawer(drawerDestinations),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: navigationBackgroundColor,
            leading: fabInRail ? floatingActionButton : null,
            destinations: [
              for (final destination in railDestinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon, color: navigationBackgroundColor == null ? null : Colors.black),
                  label: Text(destination.title),
                ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected ?? (_) {},
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: body,
          ),
        ],
      ),
      floatingActionButton: fabInRail ? null : floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: true,
      drawerDragStartBehavior: drawerDragStartBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
    );
  }

  Widget _buildNavigationDrawerScaffold() {
    return Scaffold(
      key: key,
      body: body,
      appBar: appBar,
      drawer: Drawer(
        child: Column(
          children: [
            if (drawerHeader != null) drawerHeader!,
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.title),
                selected: destinations.indexOf(destination) == selectedIndex,
                onTap: () => _destinationTapped(destination),
              ),
            const Spacer(),
            if (drawerFooter != null) drawerFooter!,
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: true,
      drawerDragStartBehavior: drawerDragStartBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
    );
  }

  Widget _buildPermanentDrawerScaffold() {
    return Row(
      children: [
        Drawer(
          backgroundColor: navigationBackgroundColor,
          child: Column(
            children: [
              if (drawerHeader != null) drawerHeader!,
              for (final destination in destinations)
                ListTile(
                  leading: Icon(destination.icon),
                  title: Text(destination.title),
                  selected: destinations.indexOf(destination) == selectedIndex,
                  onTap: () => _destinationTapped(destination),
                  selectedColor: navigationBackgroundColor == null ? null : Colors.grey.shade200,
                  iconColor: navigationBackgroundColor == null ? null : Colors.black,
                ),
              const Spacer(),
              if (drawerFooter != null) drawerFooter!,
            ],
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
        ),
        Expanded(
          child: Scaffold(
            key: key,
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            floatingActionButtonAnimator: floatingActionButtonAnimator,
            persistentFooterButtons: persistentFooterButtons,
            endDrawer: endDrawer,
            bottomSheet: bottomSheet,
            backgroundColor: backgroundColor,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            primary: true,
            drawerDragStartBehavior: drawerDragStartBehavior,
            extendBody: extendBody,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            drawerScrimColor: drawerScrimColor,
            drawerEdgeDragWidth: drawerEdgeDragWidth,
            drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
            endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final NavigationTypeResolver navigationTypeResolver =
        this.navigationTypeResolver ?? _defaultNavigationTypeResolver;
    final navigationType = navigationTypeResolver(context);
    switch (navigationType) {
      case NavigationType.bottom:
        return _buildBottomNavigationScaffold();
      case NavigationType.rail:
        return _buildNavigationRailScaffold();
      case NavigationType.drawer:
        return _buildNavigationDrawerScaffold();
      case NavigationType.permanentDrawer:
        return _buildPermanentDrawerScaffold();
    }
  }

  void _destinationTapped(AdaptiveScaffoldDestination destination) {
    final index = destinations.indexOf(destination);
    if (index != selectedIndex) {
      onDestinationSelected?.call(index);
    }
  }
}

bool _isLargeScreen(BuildContext context) =>
    getWindowType(context) >= AdaptiveWindowType.large;
bool _isMediumScreen(BuildContext context) =>
    getWindowType(context) == AdaptiveWindowType.medium;