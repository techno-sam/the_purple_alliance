import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_auth/http_auth.dart' as http_auth;

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => host.endsWith(".local");
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
  late final http.BaseClient client;

  Connection(this.url, String username, String password) {
    client = http_auth.DigestAuthClient(username, password);
  }
}

/// Checks for a connection, without needing correct credentials
Future<bool> testUnauthorizedConnection(String url) async {
  http.Response response;
  try {
    response = await http.get(_getUri(url, 'check_online')).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    return false;
  } catch (e) {
    print('Connection error: $e');
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
  try {
    response = await connection.client.get(_getUri(connection.url, 'check_auth')).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    return false;
  } catch (e) {
    print('Connection error: $e');
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
  try {
    response = await connection.client.get(_getUri(connection.url, 'scheme.json'));
  } catch (e) {
    print('Connection error: $e');
    return [];
  }
  if (response.statusCode == 200) {
    var decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      print("Decoded: $decoded");
      return decoded;
    }
  }
  return [];
}

Future<Map<String, dynamic>> getServerMeta(Connection connection) async {
  http.Response response;
  try {
    response = await connection.client.get(_getUri(connection.url, 'meta.json'));
  } catch (e) {
    print('Connection error: $e');
    return {};
  }
  if (response.statusCode == 200) {
    var decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      print("Decoded: $decoded");
      return decoded;
    }
  }
  return {};
}

Future<Map<String, dynamic>> getTeamData(Connection connection) async {
  http.Response response;
  try {
    response = await connection.client.get(_getUri(connection.url, 'data.json'));
  } catch (e) {
    rethrow;
  }
  if (response.statusCode == 200) {
    var decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      print("Decoded: $decoded");
      return decoded;
    } else {
      throw "Bad data format on fetch ${decoded.runtimeType}, expected Map<String, dynamic>";
    }
  } else {
    throw "Bad status code on fetch: ${response.statusCode}";
  }
}

Future<void> sendDeltas(Connection connection, Map<String, dynamic> data) async {
  http.Response response;
  try {
    response = await connection.client.post(_getUri(connection.url, 'update'), body: jsonEncode(data));
  } catch (e) {
    rethrow;
  }
  if (response.statusCode == 200) {
    print("Sent deltas");
  } else {
    throw "Bad status code on send: ${response.statusCode}";
  }
}