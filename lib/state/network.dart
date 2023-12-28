import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_auth/http_auth.dart' as http_auth;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:crypto/crypto.dart' as crypto;
import 'package:the_purple_alliance/utils/util.dart';

import 'images/image_record.dart';

String sha256Hash(Uint8List data) {
  var digest = crypto.sha256.convert(data).toString();
  return digest;
}

String sha256HashString(String data) {
  return sha256Hash(const Utf8Encoder().convert(data));
}

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      //log('bad certificate callback for $host:$port');
      return port != 443;
    };
  }
}

Uri _getUri(String url, String path) {
  if (!url.endsWith("/")) {
    url += "/";
  }
  return Uri.parse(url + path);
}

void _setupDevOverrides() {
  if (kDebugMode || true) {
    //log("Enabling debug http overrides in unauthorized connection test");
    HttpOverrides.global = DevHttpOverrides();
  }
}

/// Checks for a connection, without needing correct credentials
Future<bool> testUnauthorizedConnection(String url) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await http.get(_getUri(url, 'check_online')).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    return false;
  } catch (e) {
    log('Connection error (testUnauthorizedConnection): $e');
    return false;
  }
  if (response.statusCode == 200) {
    return response.body == "online";
  } else {
    return false;
  }
}

enum _CallType<T, R> {
  testAuthorizedConnection<void, bool>(),
  getScheme<void, List<dynamic>>(),
  getServerMeta<void, Map<String, dynamic>>(),
  getTeamData<void, Map<String, dynamic>>(),
  getImage<String, Uint8List?>(),
  getExistingUuids<void, List<String>?>(),
  getImageMeta<String, ImageRecord?>(),
  uploadImage<Pair<ImageRecord, Uint8List>, void>(),
  sendDeltas<Map<String, dynamic>, void>(),
  cleanup<void, void>()
  ;
  
  R cast(dynamic fut) {
    return fut as R;
  }
}

class _Initializer {
  final String url;
  final String username;
  final String password;

  _Initializer({required this.url, required this.username, required this.password});
}

class _IsolatedCall<T, R> {
  final _CallType<T, R> type;
  final T arg;
  final int id;

  _IsolatedCall({required this.type, required this.arg, required this.id});
}

class _IsolatedReturn<T, R> {
  final _CallType<T, R> type;
  final R ret;
  final int id;

  _IsolatedReturn({required this.type, required this.ret, required this.id});
}

abstract class Connection {
  abstract final String url;

  Future<bool> testAuthorizedConnection();

  Future<List<dynamic>> getScheme();

  Future<Map<String, dynamic>> getServerMeta();

  Future<Map<String, dynamic>> getTeamData();

  Future<Uint8List?> getImage(String hash);

  Future<List<String>?> getExistingUuids();

  Future<ImageRecord?> getImageMeta(String uuid);

  Future<void> uploadImage(ImageRecord record, Uint8List data);

  Future<void> sendDeltas(Map<String, dynamic> data);

  void cleanup();

  static Connection make(String url, String username, String password) {
    return _LocalConnection(url, username, password);
  }
}

class _MultiFirstPortWrapper {
  final ReceivePort _port;
  final List<dynamic> _messages = [];
  final List<Completer<dynamic>> _completers = [];

  Future<dynamic> get first async {
    if (_messages.isNotEmpty) {
      return _messages.removeAt(0);
    } else {
      Completer<dynamic> comp = Completer();
      _completers.add(comp);
      return comp.future;
    }
  }

  _MultiFirstPortWrapper(ReceivePort port): _port = port {
    _port.listen((message) {
      if (_completers.isNotEmpty) {
        _completers.removeAt(0).complete(message);
      } else {
        _messages.add(message);
      }
    });
  }

  Future<Never> listen(Future<void> Function(dynamic message) onData) async {
    while (true) {
      final message = await first;
      await onData(message);
    }
  }
}

Future<Never> _networkHandler(SendPort sendPort) async {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final receiveWrapper = _MultiFirstPortWrapper(receivePort);
  
  _Initializer init = await receiveWrapper.first;
  _IsolatedConnection conn = _IsolatedConnection(init.url, init.username, init.password);

  await receiveWrapper.listen((message) async {
    if (message is _IsolatedCall) {
      try {
        var ret = await conn._handleCall(message.type, message.arg);
        sendPort.send(_IsolatedReturn(type: message.type, ret: ret, id: message.id));
      } catch (e) {
        log("Error in network handler: $e");
      }
    } else {
      log("Oops, got a message that wasn't a call: $message");
    }
  });
}

class _LocalConnection implements Connection {
  @override
  final String url;
  final String _username;
  final String _password;

  int _requestId = 0;
  final Map<int, Completer<dynamic>> _requests = {};
  late final Isolate _isolate;
  late final ReceivePort _port;
  late final SendPort _sendPort;
  bool _closed = false;
  bool _initialized = false;

  _LocalConnection(this.url, String username, String password):
        _username = username, _password = password;
  
  Future<void> _initPorts() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _port = ReceivePort('network handler');
    final receiveWrapper = _MultiFirstPortWrapper(_port);
    
    // Spawn isolate
    _isolate = await Isolate.spawn(_networkHandler, _port.sendPort);
    
    _sendPort = await receiveWrapper.first;
    _sendPort.send(_Initializer(url: url, username: _username, password: _password));
    receiveWrapper.listen((message) async {
      if (message is _IsolatedReturn) {
        if (_requests.containsKey(message.id)) {
          _requests[message.id]!.complete(message.type.cast(message.ret));
        } else {
          log("Oops, got a message for an expired id: ${message.id}");
        }
      } else {
        log("Oops, got a message that wasn't a return: $message");
      }
    });
    return;
  }
  
  Future<R> _callIsolated<T, R>(_CallType<T, R> type, T arg) async {
    if (_closed) {
      throw "Connection closed";
    }
    await _initPorts();
    final int id = _requestId++;
    var result = Completer<R>();
    _requests[id] = result;
    _sendPort.send(_IsolatedCall(type: type, arg: arg, id: id));

    return result.future;
  }
  
  @override
  Future<void> cleanup() async {
    if (_closed) {
      throw "Connection already closed";
    }
    await _callIsolated<void, void>(_CallType.cleanup, null);
    _isolate.kill();
    _port.close();
    _closed = true;
  }
  
  @override
  Future<bool> testAuthorizedConnection() {
    return _callIsolated<void, bool>(_CallType.testAuthorizedConnection, null);
  }
  
  @override
  Future<List<dynamic>> getScheme() {
    return _callIsolated<void, List<dynamic>>(_CallType.getScheme, null);
  }
  
  @override
  Future<Map<String, dynamic>> getServerMeta() {
    return _callIsolated<void, Map<String, dynamic>>(_CallType.getServerMeta, null);
  }
  
  @override
  Future<Map<String, dynamic>> getTeamData() {
    return _callIsolated<void, Map<String, dynamic>>(_CallType.getTeamData, null);
  }
  
  @override
  Future<Uint8List?> getImage(String hash) {
    return _callIsolated<String, Uint8List?>(_CallType.getImage, hash);
  }
  
  @override
  Future<List<String>?> getExistingUuids() {
    return _callIsolated<void, List<String>?>(_CallType.getExistingUuids, null);
  }
  
  @override
  Future<ImageRecord?> getImageMeta(String uuid) {
    return _callIsolated<String, ImageRecord?>(_CallType.getImageMeta, uuid);
  }
  
  @override
  Future<void> uploadImage(ImageRecord record, Uint8List data) {
    return _callIsolated<Pair<ImageRecord, Uint8List>, void>(_CallType.uploadImage, Pair.of(record, data));
  }
  
  @override
  Future<void> sendDeltas(Map<String, dynamic> data) {
    return _callIsolated<Map<String, dynamic>, void>(_CallType.sendDeltas, data);
  }
}

class _IsolatedConnection implements Connection {
  @override
  final String url;
  final String _username;
  final String _password;
  late final http_auth.DigestAuthClient _client;

  _IsolatedConnection(this.url, String username, String password):
        _username = username, _password = password {
    _setupDevOverrides();
    _client = http_auth.DigestAuthClient(_username, _password);
  }

  @override
  Future<bool> testAuthorizedConnection() async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'check_auth'))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return false;
    } catch (e) {
      log('Connection error (testAuthorizedConnection): $e');
      return false;
    }
    if (response.statusCode == 200) {
      return response.body == 'authorized';
    } else {
      return false;
    }
  }

  @override
  Future<List<dynamic>> getScheme() async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'scheme.json'));
    } catch (e) {
      log('Connection error (getScheme): $e');
      return [];
    }
    if (response.statusCode == 200) {
      var decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) {
        log("Decoded: $decoded");
        return decoded;
      }
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getServerMeta() async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'meta.json'));
    } catch (e) {
      log('Connection error (getServerMeta): $e');
      return {};
    }
    if (response.statusCode == 200) {
      var decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        log("Decoded: $decoded");
        return decoded;
      }
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> getTeamData() async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'data.json'));
    } catch (e) {
      rethrow;
    }
    if (response.statusCode == 200) {
      var decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        log("Decoded: $decoded");
        return decoded;
      } else {
        throw "Bad data format on fetch ${decoded
            .runtimeType}, expected Map<String, dynamic>";
      }
    } else {
      throw "Bad status code on fetch: ${response.statusCode}";
    }
  }

  @override
  Future<Uint8List?> getImage(String hash) async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'image/$hash'));
    } catch (e) {
      log('Image download error: $e');
      return null;
    }
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      log('Invalid status code for image ${response.statusCode}');
      return null;
    }
  }

  @override
  Future<List<String>?> getExistingUuids() async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'image_hashes.txt'));
    } catch (e) {
      log('Image hashes download failed: $e');
      return null;
    }
    if (response.statusCode == 200) {
      return response.body.split("\n")
          .where((element) => element != '')
          .toList();
    } else {
      log('Invalid status code for hash download: ${response.statusCode}');
      return null;
    }
  }

  @override
  Future<ImageRecord?> getImageMeta(String uuid) async {
    http.Response response;
    _setupDevOverrides();
    try {
      response =
      await _client.get(_getUri(url, 'image_meta/$uuid'));
    } catch (e) {
      log('Image meta download error: $e');
      return null;
    }
    if (response.statusCode == 200) {
      var decoded = await compute(jsonDecode, response.body);
      if (decoded is Map<String, dynamic>) {
        String author = typeOr(decoded["author"], "Unknown");
        List<String> tags = typeOr(decoded["tags"], <dynamic>[]).whereType<
            String>().toList();
        int team = decoded["team"]; // the team is essential, if we don't get it, there is nothing to be shown
        return ImageRecord(uuid, author, tags, team);
      } else {
        log('Invalid meta info for image $decoded');
        return null;
      }
    } else {
      log('Invalid status code for image meta ${response.statusCode}');
      return null;
    }
  }

  @override
  Future<void> uploadImage(ImageRecord record, Uint8List data) async {
    http.StreamedResponse response;
    _setupDevOverrides();
    try {
      http.MultipartFile makeFile() => http.MultipartFile.fromBytes(
          'image', data, contentType: http_parser.MediaType("image", "jpg"),
          filename: 'upload.jpg');
      var request = http.MultipartRequest(
          'POST', _getUri(url, 'image_upload'))
        ..fields['tags'] = jsonEncode(record.tags)
        ..fields['uuid'] = record.uuid
        ..fields['team'] = '${record.team}'
        ..files.add(makeFile());
      _client.registerMultipartFileRestorer(
          makeFile, clearFirst: true);
      response = await _client.send(request);
      _client.clearMultipartFileRestorers();
    } catch (e) {
      rethrow;
    }
    if (response.statusCode == 200) {
      log("Uploaded Image");
    } else {
      throw "Bad status code on image upload: ${response.statusCode}";
    }
  }

  @override
  Future<void> sendDeltas(Map<String, dynamic> data) async {
    http.Response response;
    _setupDevOverrides();
    try {
      response = await _client.post(
          _getUri(url, 'update'), body: jsonEncode(data));
    } catch (e) {
      rethrow;
    }
    if (response.statusCode == 200) {
      log("Sent deltas");
    } else {
      throw "Bad status code on send: ${response.statusCode}";
    }
  }

  @override
  void cleanup() {
    _client.close();
  }

  Future<R> _handleCall<T, R>(_CallType<T, R> type, T arg) async {
    // ignore: unnecessary_cast
    switch (type as _CallType<dynamic, dynamic>) {
      case _CallType.testAuthorizedConnection:
        return await testAuthorizedConnection() as R;
      case _CallType.getScheme:
        return await getScheme() as R;
      case _CallType.getServerMeta:
        return await getServerMeta() as R;
      case _CallType.getTeamData:
        return await getTeamData() as R;
      case _CallType.getImage:
        return await getImage(arg as String) as R;
      case _CallType.getExistingUuids:
        return await getExistingUuids() as R;
      case _CallType.getImageMeta:
        return await getImageMeta(arg as String) as R;
      case _CallType.uploadImage:
        final a = arg as Pair<ImageRecord, Uint8List>;
        return await uploadImage(a.first, a.second) as R;
      case _CallType.sendDeltas:
        return await sendDeltas(arg as Map<String, dynamic>) as R;
      case _CallType.cleanup:
        cleanup();
        return null as R;
    }
  }
}