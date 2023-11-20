import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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