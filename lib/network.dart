import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_auth/http_auth.dart' as http_auth;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:crypto/crypto.dart' as crypto;
import 'package:the_purple_alliance/data_manager.dart';
import 'package:the_purple_alliance/util.dart';

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

class Connection {
  final String url;
  late final http_auth.DigestAuthClient client;

  Connection(this.url, String username, String password) {
    _setupDevOverrides();
    client = http_auth.DigestAuthClient(username, password);
  }
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

Future<bool> testAuthorizedConnection(Connection connection) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'check_auth')).timeout(const Duration(seconds: 10));
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

Future<List<dynamic>> getScheme(Connection connection) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'scheme.json'));
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

Future<Map<String, dynamic>> getServerMeta(Connection connection) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'meta.json'));
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

Future<Map<String, dynamic>> getTeamData(Connection connection) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'data.json'));
  } catch (e) {
    rethrow;
  }
  if (response.statusCode == 200) {
    var decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      log("Decoded: $decoded");
      return decoded;
    } else {
      throw "Bad data format on fetch ${decoded.runtimeType}, expected Map<String, dynamic>";
    }
  } else {
    throw "Bad status code on fetch: ${response.statusCode}";
  }
}

Future<Uint8List?> getImage(Connection connection, String hash) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'image/$hash'));
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

Future<List<String>?> getExistingUuids(Connection connection) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'image_hashes.txt'));
  } catch (e) {
    log('Image hashes download failed: $e');
    return null;
  }
  if (response.statusCode == 200) {
    return response.body.split("\n").where((element) => element != '').toList();
  } else {
    log('Invalid status code for hash download: ${response.statusCode}');
    return null;
  }
}

Future<ImageRecord?> getImageMeta(Connection connection, String uuid) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.get(_getUri(connection.url, 'image_meta/$uuid'));
  } catch (e) {
    log('Image meta download error: $e');
    return null;
  }
  if (response.statusCode == 200) {
    var decoded = await compute(jsonDecode, response.body);
    if (decoded is Map<String, dynamic>) {
      String author = typeOr(decoded["author"], "Unknown");
      List<String> tags = typeOr(decoded["tags"], <dynamic>[]).whereType<String>().toList();
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

Future<void> uploadImage(Connection connection, ImageRecord record, Uint8List data)  async {
  http.StreamedResponse response;
  _setupDevOverrides();
  try {
    http.MultipartFile makeFile() => http.MultipartFile.fromBytes('image', data, contentType: http_parser.MediaType("image", "jpg"), filename: 'upload.jpg');
    var request = http.MultipartRequest('POST', _getUri(connection.url, 'image_upload'))
          ..fields['tags'] = jsonEncode(record.tags)
          ..fields['uuid'] = record.uuid
          ..fields['team'] = '${record.team}'
          ..files.add(makeFile());
    connection.client.registerMultipartFileRestorer(makeFile, clearFirst: true);
    response = await connection.client.send(request);
    connection.client.clearMultipartFileRestorers();
  } catch (e) {
    rethrow;
  }
  if (response.statusCode == 200) {
    log("Uploaded Image");
  } else {
    throw "Bad status code on image upload: ${response.statusCode}";
  }
}

Future<void> sendDeltas(Connection connection, Map<String, dynamic> data) async {
  http.Response response;
  _setupDevOverrides();
  try {
    response = await connection.client.post(_getUri(connection.url, 'update'), body: jsonEncode(data));
  } catch (e) {
    rethrow;
  }
  if (response.statusCode == 200) {
    log("Sent deltas");
  } else {
    throw "Bad status code on send: ${response.statusCode}";
  }
}