import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:the_purple_alliance/network.dart';
import 'package:the_purple_alliance/util.dart';
import 'package:the_purple_alliance/widgets.dart';

final Map<Type, DataValue Function(Map<String, dynamic>)> _valueTypes = {};

int _generateTimestamp() {
  return DateTime.now().toUtc().millisecondsSinceEpoch;
}

abstract class DataValue {
  int _lastEdited = -1;
  bool get _localChanges => _lastEdited != -1;
  void Function() changeNotifier = () {};
  void fromJson(dynamic data);
  
  static dynamic load(Type t, Map<String, dynamic> initData) {
    if (_valueTypes.containsKey(t)) {
      return _valueTypes[t]!(initData);
    } else {
      throw "Type $t is not registered";
    }
  }

  dynamic toJson();

  void reset() {
    _lastEdited = -1;
  }

  void markChange() {
    _lastEdited = _generateTimestamp();
  }

  void setChangeNotifier(void Function() changeNotifier) {
    this.changeNotifier = changeNotifier;
  }
}

mixin TimestampSpecialBehaviorMixin on DataValue {
  /// localOld is true if the data is from the server, and the local data is older - if loading from disk and a timestamp is present, localOld will always be true
  ///
  /// Returns true if the current timestamp should be kept, returns false if it should be set to -1
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk);

  /// Only called if no timestamp is present in the read data
  ///
  /// Returns true if the current timestamp should be kept, returns false if it should be set to -1
  bool fromJsonBackup(dynamic data, bool fromDisk);
}

class TextDataValue extends DataValue {

  String _value = "";

  @override
  void fromJson(dynamic data) {
    assert (data is String);
    _value = data;
  }

  @override
  toJson() {
    return _value;
  }

  @override
  void reset() {
    super.reset();
    _value = "";
  }

  static dynamic getDefault() {
    return "";
  }

  String get value => _value;

  set value(String value) {
    _value = value;
    markChange();
  }
}

class DropdownDataValue extends DataValue {
  String _value = "";
  late final List<String> _options;
  late final String _default;

  DropdownDataValue(Map<String, dynamic> initData) {
    _options = List<String>.from(initData["options"]);
    _value = initData.containsKey("default") ? initData["default"] : _options[0];
    if (!_options.contains(_value)) {
      _value = _options[0];
    }
    _default = _value;
  }

  @override
  void fromJson(data) {
    assert (data is String);
    if (_options.contains(data)) {
      _value = data;
    }
  }

  @override
  toJson() {
    return _value;
  }

  @override
  void reset() {
    super.reset();
    _value = _default;
  }

  List<String> get options => List.unmodifiable(_options);

  String get value => _value;
  set value(String value) {
    if (_options.contains(value)) {
      _value = value;
      markChange();
    }
  }
}

class StarRatingDataValue extends DataValue with TimestampSpecialBehaviorMixin {
  double? _personalValue;
  double? get personalValue => _personalValue;
  set personalValue(double? value) {
    _personalValue = value;
    markChange();
  }

  double? averageValue;

  StarRatingDataValue();

  @override
  void fromJson(data) {
    assert (data is Map<String, dynamic>);
    _personalValue = data["personal_value"];
    averageValue = data["average_value"];
  }

  @override
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk) {
    assert (data is Map<String, dynamic>);
    // we always set the average value, since that is server-calculated
    // we only set the personal value if it is newer than the local value, or if the local value does not exist
    averageValue = data["average_value"];
    if (localOld || _personalValue == null) {
      _personalValue = data["personal_value"];
      return false; // data is now completely from the server, update timestamp to match
    }
    return true; // our data is still potentially unique, keep the timestamp
  }

  @override
  bool fromJsonBackup(dynamic data, bool fromDisk) {
    fromJson(data);
    return false; // data is now completely from the server, update timestamp to match
  }

  @override
  toJson() {
    return {
      "personal_value": _personalValue,
      "average_value": averageValue, // this is, of course, ignored by the server and overriden with a more accurate average value - the server also overrides the time-based system
    };
  }
}

class CommentsDataValue extends DataValue with TimestampSpecialBehaviorMixin {
  String? _personalComment;
  String? get personalComment => _personalComment;
  set personalComment(String? value) {
    _personalComment = value;
    markChange();
  }

  Map<String, dynamic> otherComments = {};

  Map<String, String> get stringComments {
    Map<String, String> out = {};
    otherComments.forEach((key, value) {
      if (value is String) {
        out[key] = value;
      }
    });
    return out;
  }

  CommentsDataValue();

  @override
  void fromJson(data) {
    assert (data is Map<String, dynamic>);
    _personalComment = data["personal_comment"];
    otherComments = data["other_comments"];
  }

  @override
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk) {
    assert (data is Map<String, dynamic>);
    // we always set the other comments, since those is server-provided
    // we only set the personal comment if it is newer than the local value, or if the local value does not exist
    otherComments = data["other_comments"];
    if (localOld || _personalComment == null) {
      _personalComment = data["personal_comment"];
      return false; // data is now completely from the server, update timestamp to match
    }
    return true; // our data is still potentially unique, keep the timestamp
  }

  @override
  bool fromJsonBackup(dynamic data, bool fromDisk) {
    fromJson(data);
    return false; // data is now completely from the server, update timestamp to match
  }

  @override
  toJson() {
    return {
      "personal_comment": _personalComment,
      "other_comments": otherComments, // this is, of course, ignored by the server, but it is needed to save to disc locally
    };
  }

  static String getDefault() {
    return "";
  }
}

/// Simplification wrapper for DataValue constructors that do not take any initialization data
DataValue Function(Map<String, dynamic>) _s(DataValue Function() f) {
  return (_) {
    return f();
  };
}

void initializeValueHolders() {
  _valueTypes.clear();
  _valueTypes[TextDataValue] = _s(TextDataValue.new);
  _valueTypes[DropdownDataValue] = DropdownDataValue.new;
  _valueTypes[StarRatingDataValue] = _s(StarRatingDataValue.new);
  _valueTypes[CommentsDataValue] = _s(CommentsDataValue.new);
}

class DataManager {
  final Map<String, DataValue> values = {};
  bool initialized = false;

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, DataValue> entry in values.entries) {
        if (data.containsKey(entry.key)) {
          var entryData = data[entry.key];
          if (entryData is Map<String, dynamic> && entryData.containsKey("value")) {
            bool specialTimestampHandling = entry.value is TimestampSpecialBehaviorMixin;
            if (entryData.containsKey("timestamp")) {
              var timestamp = entryData["timestamp"];
              if (timestamp is int) {
                if (timestamp >= entry.value._lastEdited || fromDisk) {
                  var keepTimestamp = false;
                  if (specialTimestampHandling) {
                    keepTimestamp = (entry.value as TimestampSpecialBehaviorMixin).fromJsonSpecial(entryData["value"], true, fromDisk); // local is always old because of the above check
                  } else {
                    entry.value.fromJson(entryData["value"]);
                  }
                  if (!keepTimestamp || fromDisk) {
                    entry.value._lastEdited = fromDisk ? entryData["timestamp"] : -1;
                  }
                }
              } else if (fromDisk) {
                log("Invalid timestamp: $timestamp");
                if (specialTimestampHandling) {
                  (entry.value as TimestampSpecialBehaviorMixin).fromJsonBackup(entryData["value"], fromDisk);
                } else {
                  entry.value.fromJson(entryData["value"]);
                }
                entry.value._lastEdited = _generateTimestamp();
              }
            } else {
              var keepTimestamp = false;
              if (specialTimestampHandling) {
                keepTimestamp = (entry.value as TimestampSpecialBehaviorMixin).fromJsonBackup(entryData["value"], fromDisk);
              } else {
                entry.value.fromJson(entryData["value"]);
              }
              if (!keepTimestamp || fromDisk) { // don't care what the data value asks, if we have no timestamp set yet, and we are loading from disk, it should be set to the current time
                entry.value._lastEdited = fromDisk ? _generateTimestamp() : -1;
              }
            }
          } else {
            entry.value.reset();
          }
        } else {
          entry.value.reset();
        }
      }
    } else {
      for (DataValue value in values.values) {
        value.reset();
      }
    }
  }

  Map<String, dynamic> save() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      data[entry.key] = {
        "value": entry.value.toJson(),
        "timestamp": entry.value._lastEdited,
      };
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      if (entry.value._localChanges) {
        data[entry.key] = {
          "value": entry.value.toJson(),
          "timestamp": entry.value._lastEdited,
        };
      }
    }
    return data;
  }
}

class TeamDataManager {
  final Map<int, DataManager> managers = {};
  final void Function(DataManager) initializeManager;

  TeamDataManager(this.initializeManager);

  DataManager getManager(int teamNumber) {
    if (managers.containsKey(teamNumber) && managers[teamNumber] != null) {
      return managers[teamNumber]!;
    } else {
      var manager = DataManager();
      managers[teamNumber] = manager;
      return manager;
    }
  }

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, dynamic> entry in data.entries) {
        var teamNumber = int.tryParse(entry.key);
        if (teamNumber != null && (entry.value == null || entry.value is Map<String, dynamic>)) {
          var dataManager = managers.putIfAbsent(teamNumber, DataManager.new);
          if (!dataManager.initialized) {
            initializeManager(dataManager);
            dataManager.initialized = true;
          }
          dataManager.load(entry.value, fromDisk);
        }
      }
    } else {
      managers.clear();
    }
  }

  Map<String, dynamic> save() {
    Map<String, dynamic> data = {};
    for (MapEntry<int, DataManager> entry in managers.entries) {
      data["${entry.key}"] = entry.value.save();
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<int, DataManager> entry in managers.entries) {
      var deltas = entry.value.saveNetworkDeltas();
      if (deltas.isNotEmpty) {
        data["${entry.key}"] = deltas;
      }
    }
    return data;
  }
}

class ImageRecord {
  final String hash;
  final String author;
  final List<String> tags;
  final int team;

  ImageRecord(this.hash, this.author, this.tags, this.team) {
    for (var character in hash.characters) {
      if (!("0123456789abcdef".contains(character))) {
        throw "Illegal hash passed to image record, aborting";
      }
    }
  }

  bool tagsEqual(ImageRecord other) {
    tags.sort();
    other.tags.sort();
    if (tags.length != other.tags.length) {
      return false;
    }
    for (int i = 0; i < tags.length; i++) {
      if (tags[i] != other.tags[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ImageRecord) {
      return false;
    }
    return hash == other.hash && author == other.author && tagsEqual(other) && team == other.team;
  }

  static ImageRecord? fromJson(dynamic item) {
    if (item is Map<String, dynamic>) {
      var author = item['author'];
      var tags = item['tags'];
      var hash = item['hash'];
      var team = item['team'];
      if (author is String && tags is List && hash is String && team is int) {
        return ImageRecord(hash, author, tags.whereType<String>().toList(), team);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'tags': tags,
      'hash': hash,
      'team': team
    };
  }

  @override
  int get hashCode {
    return Object.hash(hash, author, tags, team);
  }
}

const int _jpgQuality = 90;

Future<String> get imagesPath async {
  final directory = await getApplicationDocumentsDirectory();

  return "${directory.path}/the_purple_alliance/images";
}

Future<File> getImageFile(String hash, {bool quick = false}) async {
  assert (hash.length >= 2);
  final path = await imagesPath;
  final imagePath = '$path/${hash.substring(0, 2)}';
  if (!quick) {
    await Directory(imagePath).create(recursive: true);
  }
  return File('$imagePath/$hash.jpg');
}



class ImageSyncManager extends ChangeNotifier {
  final List<Pair<String, ImageRecord>> _toCopy = []; // images needing to be copied from temp storage to permanent image cache don't write to disk (cache images may no longer exist)
  final Map<String, ImageRecord> _copied = {}; // already copied images, don't write to disk (cache images may no longer exist)
  final List<Pair<String, ImageRecord>> _toUpload = []; // images to be uploaded, key is a path to the image if it is in temp storage (write to disk)
  final List<String> _toDownload = []; // just a list of hashes, metadata is not yet present (don't write to disk, dynamically determined)
  Set<String> _downloadedHashes = {}; // write to disk, this is what we already have
  final List<ImageRecord> _knownImages = []; // write to disk, this is a cached version of already synced stuff
  late Connection Function() _getConnection;
  late ImageSyncMode Function() _getMode;
  late int? Function() _getSelectedTeam;
  Set<String> get downloadedHashes => _downloadedHashes;
  List<ImageRecord> get knownImages => _knownImages;
  Iterable<ImageRecord> get notDownloaded => _knownImages.where((element) => !_downloadedHashes.contains(element.hash));
  
  late Timer _transferTimer;
  bool _alreadyTransferring = false;
  
  ImageSyncManager(Connection Function() getConnection, ImageSyncMode Function() getMode, int? Function() getSelectedTeam) {
    _getConnection = getConnection;
    _getMode = getMode;
    _getSelectedTeam = getSelectedTeam;
    _transferTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_alreadyTransferring) {
        return;
      }
      _alreadyTransferring = true;
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
    _downloadedHashes.clear();
    _knownImages.clear();
  }
  
  Future<void> addTakenPicture(int team, String author, List<String> tags, String file) async {
    File imageFile = File(file);
    if (!await imageFile.exists()) {
      return;
    }
    _toUpload.add(Pair.of(file, ImageRecord("", author, tags, team)));
    _toCopy.add(Pair.of(file, ImageRecord(sha256Hash(await imageFile.readAsBytes()), author, tags, team)));
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
    String hash = record.hash;
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
    _toDownload.addAll(records.where((element) => mode == ImageSyncMode.all || element.team == teamNumber).map((element) => element.hash));
  }

  Future<void> runMetaDownload(Connection connection) async {
    Pair<List<ImageRecord>, List<String>> data = await compute2((conn, knownImg) async {
      List<String>? hashes = await compute(getExistingHashes, conn);
      if (hashes == null) {
        return Pair.of([], []);
      }
      List<String> toRemove = [];
      for (String hash in knownImg.map((element) => element.hash)) { // don't need to fetch existing meta
        if (hashes.contains(hash)) {
          hashes.remove(hash);
        } else {
          toRemove.add(hash);
        }
      }
      List<ImageRecord> newImg = [];
      for (String hash in hashes) {
        ImageRecord? record = await compute2(getImageMeta, conn, hash);
        if (record != null) {
          newImg.add(record);
        }
      }
      return Pair.of(newImg, toRemove);
    }, connection, _knownImages);
    List<ImageRecord> newImages = data.first;
    List<String> removedHashes = data.second;
    for (String toRemove in removedHashes) {
      _downloadedHashes.remove(toRemove);
      _knownImages.removeWhere((element) => element.hash == toRemove);
    }
    _knownImages.addAll(newImages);
    addToDownload(newImages);
//    _toDownload.addAll(newImages.map((element) => element.hash));
//    log('_toDownload: $_toDownload');
  }

  void queueForDownload({int? team, String? hash}) {
    var toQueue = _knownImages.where((record) {
      return (team == null || record.team == team) && (hash == null || record.hash == hash);
    }).map((record) => record.hash);
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
        _downloadedHashes.add(downloadHash);
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
        String newHash = sha256Hash(jpg);
        final destFile = await getImageFile(newHash);
        await destFile.writeAsBytes(jpg);
        log("Copied to ${destFile.path}");
        final ImageRecord record = ImageRecord(newHash, data.second.author, data.second.tags, data.second.team);
        _copied[data.first] = record;
//        _loadedImages.add(data.second);
        _downloadedHashes.add(newHash);
        _knownImages.add(record);
        notifyListeners();
      }
    }
  }

  Future<void> runUpload(Connection connection) async { //should be run in timer
    if (_toUpload.isNotEmpty) {
      final Pair<String, ImageRecord> data = _toUpload.removeAt(0);
      try {
        File srcFile;
        bool needsConversion = false;
        var record = data.second;
        if (_copied.keys.contains(data.first)) {
          record = _copied[data.first]!;
          srcFile = await getImageFile(record.hash);
        } else {
          srcFile = File(data.first);
          needsConversion = true;
          if (!(await srcFile.exists())) {
            srcFile = await getImageFile(record.hash);
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
        _downloadedHashes = downloadedHashes.whereType<String>().toSet();
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
      var toDownload = _knownImages.map((element) => element.hash).toList();
      for (String hash in _downloadedHashes) {
        toDownload.remove(hash);
      }
      _toDownload.addAll(toDownload);
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
      'downloaded_hashes': _downloadedHashes.toList(),
    });
    final file = await _dataFile;
    return await compute(file.writeAsString, data);
  }
}