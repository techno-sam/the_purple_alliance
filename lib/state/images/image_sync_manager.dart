import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';

import 'package:the_purple_alliance/state/network.dart';
import 'package:the_purple_alliance/utils/util.dart';
import 'package:the_purple_alliance/widgets/image_sync_selector.dart';

import 'image_record.dart';



const int _jpgQuality = 90;

Future<String> get imagesPath async {
  final directory = await getApplicationDocumentsDirectory();

  return "${directory.path}/the_purple_alliance/images";
}

Future<String> getImagePath(String uuid, {bool quick = false}) async {
  assert (uuid.length >= 2);
  final path = await imagesPath;
  final imagePath = '$path/${uuid.substring(0, 2)}';
  if (!quick) {
    await Directory(imagePath).create(recursive: true);
  }
  return '$imagePath/$uuid.jpg';
}

Set<String> _nonExistentUUIDs = {};

Future<File> getImageFile(String uuid, {bool quick = false}) async {
  final file = File(await getImagePath(uuid, quick: quick));
  if (!await file.exists()) {
    _nonExistentUUIDs.add(uuid);
  }
  return file;
}


class ImageSyncManager extends ChangeNotifier {
  final List<Pair<String, ImageRecord>> _toCopy = []; // images needing to be copied from temp storage to permanent image cache don't write to disk (cache images may no longer exist)
  final Map<String, ImageRecord> _copied = {}; // already copied images, don't write to disk (cache images may no longer exist)
  final List<Pair<String, ImageRecord>> _toUpload = []; // images to be uploaded, key is a path to the image if it is in temp storage (write to disk)
  final List<String> _toDownload = []; // just a list of hashes, metadata is not yet present (don't write to disk, dynamically determined)
  Set<String> _downloadedUUIDs = {}; // write to disk, this is what we already have
  final List<ImageRecord> _knownImages = []; // write to disk, this is a cached version of already synced stuff
  late Connection Function() _getConnection;
  late ImageSyncMode Function() _getMode;
  late int? Function() _getSelectedTeam;
  late bool Function() _isReady;
  Set<String> get downloadedUUIDs => _downloadedUUIDs;
  List<ImageRecord> get knownImages => _knownImages;
  Iterable<ImageRecord> get notDownloaded => _knownImages.where((element) => !_downloadedUUIDs.contains(element.uuid));
  List<String> _serverKnownUuids = []; // write to disk, otherwise upload buttons show up when the server already knows about stuff

  bool isKnown(String uuid) => _serverKnownUuids.contains(uuid);

  Future<void> remindUpload(String uuid) async {
    if (!isKnown(uuid)) {
      ImageRecord record;
      try {
        record = _knownImages.firstWhere((element) => element.uuid == uuid);
      } on StateError {
        return;
      }
      _toUpload.add(Pair.of(await getImagePath(uuid, quick: true), record));
      await runUpload(_getConnection(), latest: true);
      await runMetaDownload(_getConnection());
    }
  }

  // ignore: unused_field
  late Timer _transferTimer;
  bool _alreadyTransferring = false;

  ImageSyncManager(Connection Function() getConnection, ImageSyncMode Function() getMode, int? Function() getSelectedTeam, bool Function() isReady) {
    _getConnection = getConnection;
    _getMode = getMode;
    _getSelectedTeam = getSelectedTeam;
    _isReady = isReady;
    _transferTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_alreadyTransferring) {
        return;
      }
      if (!_isReady()) {
        return;
      }
      _alreadyTransferring = true;
      while (_nonExistentUUIDs.isNotEmpty) {
        String nonExistentUUID = _nonExistentUUIDs.elementAt(0);
        _nonExistentUUIDs.remove(nonExistentUUID);
        _downloadedUUIDs.remove(nonExistentUUID);
      }
      await runCopy();
      final connection = _getConnection();
      await runDownload(connection);
      await runUpload(connection);
/*      if (_downloadedHashes.length < _knownImages.length) {
        _toDownload.addAll(_knownImages.map((element) => element.hash).where((v) => !_downloadedHashes.contains(v)));
      }*/
      _alreadyTransferring = false;
    });
  }

  void clear(Connection Function() getConnection) {
    _getConnection = getConnection;
    _alreadyTransferring = true;
    _toCopy.clear();
    _copied.clear();
    _toUpload.clear();
    _toDownload.clear();
    _downloadedUUIDs.clear();
    _knownImages.clear();
    _serverKnownUuids.clear();
  }

  Future<void> addTakenPicture(int team, String author, List<String> tags, String file) async {
    File imageFile = File(file);
    if (!await imageFile.exists()) {
      return;
    }
    _toCopy.add(Pair.of(file, ImageRecord(makeUUID(), author, tags, team)));
  }

  Future<String> get _localPath async {
    return await imagesPath;
  }

  Future<File> get _dataFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/data.json');
  }

  void addToDownloadManual(ImageRecord record) {
    String hash = record.uuid;
    if (!_toDownload.contains(hash)) {
      _toDownload.add(hash);
    }
  }

  void addToDownload(Iterable<ImageRecord> records) {
    ImageSyncMode mode = _getMode();
    if (mode == ImageSyncMode.manual) {
      return;
    }
    int? teamNumber = _getSelectedTeam();
    _toDownload.addAll(records.where((element) => mode == ImageSyncMode.all || element.team == teamNumber).map((element) => element.uuid));
  }

  Future<void> runMetaDownload(Connection connection) async {
    Triple<List<ImageRecord>, List<String>, List<String>> data = await compute2((conn, knownImg) async {
      List<String>? uuids = await compute(getExistingUuids, conn);
      if (uuids == null) {
        return Triple.of([], [], []);
      }
      var knownUuids = [...uuids]; // just to have a copy
      List<String> toRemove = [];
      for (String uuid in knownImg.map((element) => element.uuid)) { // don't need to fetch existing meta
        if (uuids.contains(uuid)) {
          uuids.remove(uuid);
        } else {
          toRemove.add(uuid);
        }
      }
      List<ImageRecord> newImg = [];
      for (String uuid in uuids) {
        ImageRecord? record = await compute2(getImageMeta, conn, uuid);
        if (record != null) {
          newImg.add(record);
        }
      }
      return Triple.of(newImg, toRemove, knownUuids);
    }, connection, _knownImages);
    List<ImageRecord> newImages = data.first;
    List<String> removedUuids = data.second;
    for (String toRemove in removedUuids) {
      _downloadedUUIDs.remove(toRemove);
      _knownImages.removeWhere((element) => element.uuid == toRemove);
    }
    _serverKnownUuids = data.third;
    _knownImages.addAll(newImages);
    addToDownload(newImages);
//    _toDownload.addAll(newImages.map((element) => element.uuid));
//    log('_toDownload: $_toDownload');
  }

  void queueForDownload({int? team, String? hash}) {
    var toQueue = _knownImages.where((record) {
      return (team == null || record.team == team) && (hash == null || record.uuid == hash);
    }).map((record) => record.uuid);
    _toDownload.addAll(toQueue);
  }

  Future<void> runDownload(Connection connection) async { //should be run in timer
    if (_toDownload.isNotEmpty) {
      final String downloadHash = _toDownload.removeAt(0);
      var imageData = await compute2(getImage, connection, downloadHash);//await getImage(connection, downloadTarget.hash);
      //var record = await(compute2(getImageMeta, connection, downloadHash));
      if (imageData != null) {
        var file = await getImageFile(downloadHash);
        await file.writeAsBytes(imageData, flush: true);
        _downloadedUUIDs.add(downloadHash);
//        _knownImages.add(record);
        notifyListeners();
      }
    }
  }

  Future<void> runCopy() async { //should be run in timer
    if (_toCopy.isNotEmpty) {
      final Pair<String, ImageRecord> data = _toCopy.removeAt(0);
      final sourceFile = File(data.first);
      final image = decodeImage(await sourceFile.readAsBytes(), frame: 0);
      log("Copying ${data.first}");
      if (image != null) {
        final Uint8List jpg = encodeJpg(image, quality: _jpgQuality);
        if (_knownImages.map((element) => element.uuid).contains(data.second.uuid)) {
          return;
        }
        _toUpload.add(Pair.of(data.first, data.second));
        final destFile = await getImageFile(data.second.uuid);
        await destFile.writeAsBytes(jpg);
        log("Copied to ${destFile.path}");
//        final ImageRecord record = ImageRecord(newHash, data.second.author, data.second.tags, data.second.team);
        _copied[data.first] = data.second;
//        _loadedImages.add(data.second);
        _downloadedUUIDs.add(data.second.uuid);
        _knownImages.add(data.second);
        notifyListeners();
      }
    }
  }

  Future<void> runUpload(Connection connection, {bool latest = false}) async { //should be run in timer
    if (_toUpload.isNotEmpty) {
      final Pair<String, ImageRecord> data = latest ? _toUpload.removeLast() : _toUpload.removeAt(0);
      try {
        File srcFile;
        bool needsConversion = false;
        var record = data.second;
        if (_copied.keys.contains(data.first)) {
          record = _copied[data.first]!;
          srcFile = await getImageFile(record.uuid);
        } else {
          srcFile = File(data.first);
          needsConversion = true;
          if (!(await srcFile.exists())) {
            srcFile = await getImageFile(record.uuid);
            needsConversion = false;
          }
        }
        if (!(await srcFile.exists())) {
          return;
        }
        Uint8List imgData = await srcFile.readAsBytes();
        if (needsConversion) {
          var decoded = decodeImage(imgData, frame: 0);
          if (decoded == null) {
            return;
          }
          imgData = encodeJpg(decoded, quality: _jpgQuality);
        }
        await compute3(uploadImage, connection, record, imgData);
        _serverKnownUuids.add(record.uuid);
      } catch (e) {
        log('Error during upload: $e');
        _toUpload.add(data);
      }
    }
  }

  Future<void> load() async {
    final file = await _dataFile;
    dynamic decoded;
    try {
      decoded = await compute(jsonDecode, await file.readAsString());
    } catch (e) {
      log('Exception while loading image metadata store: $e');
      return;
    }
    if (decoded is Map<String, dynamic>) {
      _knownImages.clear();
      var imageMeta = decoded['image_meta'];
      if (imageMeta is List<dynamic>) {
        for (dynamic item in imageMeta) {
          ImageRecord? record = ImageRecord.fromJson(item);
          if (record != null) {
            _knownImages.add(record);
          }
        }
      }

      var downloadedHashes = decoded['downloaded_hashes'];
      if (downloadedHashes is List) {
        _downloadedUUIDs = downloadedHashes.whereType<String>().toSet();
      }

      var uploadData = decoded['to_upload'];
      if (uploadData is Map<String, dynamic>) {
        _toUpload.clear();
        for (MapEntry<String, dynamic> entry in uploadData.entries) {
          ImageRecord? record = ImageRecord.fromJson(entry.value);
          if (record != null) {
            _toUpload.add(Pair.of(entry.key, record));
          }
        }
      }
      var toDownload = _knownImages.map((element) => element.uuid).toList();
      for (String hash in _downloadedUUIDs) {
        toDownload.remove(hash);
      }
      _toDownload.addAll(toDownload);
      var knownUuidsData = decoded['server_known_uuids'];
      if (knownUuidsData is List) {
        _serverKnownUuids = knownUuidsData.whereType<String>().toList();
      }
      notifyListeners();
    } else {
      log('Invalid data format for image metadata store ${decoded.runtimeType}');
    }
  }

  Future<File> save() async {
    List<Map<String, dynamic>> imageMeta = [
      for (ImageRecord record in _knownImages)
        record.toJson()
    ];
    Map<String, Map<String, dynamic>> uploadData = {};
    for (Pair<String, ImageRecord> entry in _toUpload) {
      uploadData[entry.first] = entry.second.toJson();
    }
    String data = await compute(jsonEncode, {
      'image_meta': imageMeta,
      'to_upload': uploadData,
      'downloaded_hashes': _downloadedUUIDs.toList(),
      'server_known_uuids': _serverKnownUuids,
    });
    final file = await _dataFile;
    return await compute(file.writeAsString, data);
  }
}