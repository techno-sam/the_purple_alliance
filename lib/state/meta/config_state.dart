import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/utils/util.dart';
import 'package:the_purple_alliance/widgets/image_sync_selector.dart';
import 'package:the_purple_alliance/widgets/sync_time_selector.dart';
import 'package:the_purple_alliance/widgets/unsaved_changes_bar.dart';

Future<File> get _configFile async {
  final path = await localPath;
  await Directory(path).create(recursive: true);
  return File('$path/config.json');
}

Future<Map<String, dynamic>> _readConfig() async {
  log("reading config...");
  var config = await readJsonFile(_configFile);
  if (config is Map<String, dynamic>) {
    return config;
  } else {
    return {};
  }
}

Future<File?> _writeConfig(Map<String, dynamic> data) async {
  return await compute2(writeJsonFile, await _configFile, data);
}

class ConfigState extends ChangeNotifier {
  final Future<void> Function() reconnectCallback;
  late final Object _privateKey;
  WeakReference<UnsavedChangesBarState>? unsavedChangesBarState;
  var __unsavedChanges = false;
  
  bool _colorfulTeams = true;
  bool _teamColorReminder = false;
  bool _teamColorIsBlue = false;
  SyncInterval _syncInterval = SyncInterval.manual;
  ImageSyncMode _imageSyncMode = ImageSyncMode.manual;
  
  // connection state
  String? _error;
  bool locked = false;
  int? _teamNumber;
  int _teamNumberInProgress = 1234;
  String? serverUrl;
  String _serverUrlInProgress = "example.com";
  String _username = "";
  String _password = "";

  ConfigState({required this.reconnectCallback, required Object privateKey}) {
    _privateKey = privateKey;
  }
  
  /*
  * Getters and Setters
   */
  int? get teamNumber => _teamNumber;
  String? get error => _error;

  bool get unsavedChanges => __unsavedChanges;
  set unsavedChanges(bool value) {
    if (__unsavedChanges != value) {
      __unsavedChanges = value;
      if ((unsavedChangesBarState?.target?.unsavedChanges ?? value) != value) {
        unsavedChangesBarState?.target?.setUnsavedChanges(value);
      }
    }
  }
  
  bool get colorfulTeams => _colorfulTeams;
  set colorfulTeams(bool value) {
    _colorfulTeams = value;
    notifyListeners();
    unsavedChanges = true;
  }

  bool get teamColorReminder => _teamColorReminder;
  set teamColorReminder(bool value) {
    _teamColorReminder = value;
    notifyListeners();
    unsavedChanges = true;
  }

  bool get teamColorIsBlue => _teamColorIsBlue;
  set teamColorIsBlue(bool value) {
    _teamColorIsBlue = value;
    notifyListeners();
    unsavedChanges = true;
  }

  SyncInterval get syncInterval => _syncInterval;
  set syncInterval(SyncInterval value) {
    unsavedChanges = true;
    _syncInterval = value;
  }

  ImageSyncMode get imageSyncMode => _imageSyncMode;
  set imageSyncMode(ImageSyncMode value) {
    unsavedChanges = true;
    _imageSyncMode = value;
  }
  
  // connection state
  int get teamNumberInProgress => _teamNumberInProgress;
  set teamNumberInProgress(int value) {
    unsavedChanges = true;
    _teamNumberInProgress = value;
  }

  String get serverUrlInProgress => _serverUrlInProgress;
  set serverUrlInProgress(String value) {
    unsavedChanges = true;
    _serverUrlInProgress = value;
  }

  String get username => _username;
  set username(String value) {
    unsavedChanges = true;
    _username = value;
  }

  String get password => _password;
  set password(String value) {
    if (locked) {
      log("Attempted password set while locked!");
      return;
    }
    unsavedChanges = true;
    _password = value;
  }

  void _ensureAuthorized(Object key) {
    if (key != _privateKey) {
      throw Exception("Unauthorized method invocation");
    }
  }

  bool setTeamNumber(int teamNumber, Object key) {
    _ensureAuthorized(key);
    return _setTeamNumber(teamNumber);
  }

  bool _setTeamNumber(int teamNumber) {
    if (!locked) {
      _teamNumber = teamNumber;
      notifyListeners();
    }
    return true;
  }

  bool setServer(String url, Object key) {
    _ensureAuthorized(key);
    return _setServer(url);
  }

  bool _setServer(String url) {
    if (!locked) {
      serverUrl = url;
      var error = verifyServerUrl(url);
      if (error != null) {
        _error = error;
        serverUrl = null;
        return false;
      }
      notifyListeners();
    }
    return true;
  }

  void setConnectionFailed(Object key) {
    _ensureAuthorized(key);
    _teamNumber = null;
    serverUrl = null;
    notifyListeners();
  }

  Map<String, dynamic> get _config {
    return {
      "colorful_teams": colorfulTeams,
      "team_color_reminder": teamColorReminder,
      "team_color_blue": teamColorIsBlue,
      "sync_interval": syncInterval.name,
      "image_sync_mode": imageSyncMode.name,
      "connection": {
        "locked": locked,
        "team_number": locked ? _teamNumber ?? teamNumberInProgress : teamNumberInProgress,
        "url": locked ? serverUrl ?? serverUrlInProgress : serverUrlInProgress,
        "username": username,
        "password": _password,
      },
    };
  }

  Future<void> _setConfig(Map<String, dynamic> jsonData) async {
    log("Hello");
    if (jsonData["colorful_teams"] is bool) {
      log("Reading colorful teams ${jsonData["colorful_teams"]}");
      colorfulTeams = jsonData["colorful_teams"];
    }
    if (jsonData["team_color_reminder"] is bool) {
      teamColorReminder = jsonData["team_color_reminder"];
    }
    if (jsonData["team_color_blue"] is bool) {
      teamColorIsBlue = jsonData["team_color_blue"];
    }
    if (jsonData["sync_interval"] is String) {
      syncInterval = SyncInterval.fromName(jsonData["sync_interval"]);
    }
    if (jsonData["image_sync_mode"] is String) {
      imageSyncMode = ImageSyncMode.fromName(jsonData["image_sync_mode"]);
    }
    if (jsonData["connection"] is Map) {
      var connection = jsonData["connection"];
      var shouldConnect = false;
      if (connection["locked"] is bool) {
        shouldConnect = connection["locked"];
      }
      if (connection["team_number"] is int) {
        teamNumberInProgress = connection["team_number"];
      } else {
        shouldConnect = false;
      }
      if (connection["url"] is String) {
        serverUrlInProgress = connection["url"];
      } else {
        shouldConnect = false;
      }
      if (connection["username"] is String) {
        username = connection["username"];
      }
      if (connection["password"] is String) {
        _password = connection["password"];
      }
      if (shouldConnect) {
        locked = false;
        log("Awaiting connection...");
        notifyListeners();
        await reconnectCallback();
        log("Connected...");
      }
    }
    notifyListeners();
    unsavedChanges = false;
  }

  Future<void> readConfig(Object key) async {
    _ensureAuthorized(key);
    await _readConfig().then((jsonData) async {
      log("Read config $jsonData");
      await _setConfig(jsonData);
    });
  }

  Future<File?> saveConfig() async {
    return await _writeConfig(_config).then((v) {
      unsavedChanges = false;
      return v;
    });
  }

  int getDisplayTeamNumber() {
    return _teamNumber ?? teamNumberInProgress;
  }

  String getDisplayUrl() {
    return serverUrl ?? serverUrlInProgress;
  }
}