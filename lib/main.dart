import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:english_words/english_words.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:the_purple_alliance/screens/main/main_page.dart';
import 'package:the_purple_alliance/state/images/image_sync_manager.dart';
import 'package:the_purple_alliance/widgets/image_sync_selector.dart';
import 'package:the_purple_alliance/widgets/scouting/scouting_layout.dart';
import 'package:the_purple_alliance/state/network.dart' as network;
import 'package:the_purple_alliance/utils/util.dart';
import 'package:the_purple_alliance/widgets/sync_time_selector.dart';
import 'package:the_purple_alliance/widgets/unsaved_changes_bar.dart';



void main() {
  initializeBuilders();
  if (kDebugMode || true) {
    log("Enabling debug http overrides");
    HttpOverrides.global = network.DevHttpOverrides();
  }
  runApp(MyApp());
}

const bool oldColors = false;

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _mainPageKey = GlobalKey<State<MainPage>>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => MyAppState(_scaffoldKey, _mainPageKey),
        child: ChangeNotifierProvider(
          create: (context) => Provider.of<MyAppState>(context, listen: false).imageSyncManager,
          child: MaterialApp(
            scaffoldMessengerKey: _scaffoldKey,
            title: 'The Purple Alliance',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.purple,
              ),
            ),
            home: MainPage(key: _mainPageKey),
          ),
        )
    );
  }
}

class MyAppState extends ChangeNotifier {
  Map<String, Map<String, dynamic>> searchConfigurations = {};
  String? _currentSearchConfiguration;

  String? get currentSearchConfiguration => _currentSearchConfiguration;

  set currentSearchConfiguration(String? currentSearchConfiguration) {
    _currentSearchConfiguration = currentSearchConfiguration;
    if (_currentSearchConfiguration != null && searchConfigurations[_currentSearchConfiguration] == null) {
      searchConfigurations[_currentSearchConfiguration!] = {};
    }
  }

  // key : configuration
  Map<String, dynamic>? get searchValues => currentSearchConfiguration == null
      ? null
      : searchConfigurations.putIfAbsent(currentSearchConfiguration!, () => {});

  var __unsavedChanges = false;
  bool get unsavedChanges => __unsavedChanges;
  set unsavedChanges(bool value) {
    if (__unsavedChanges != value) {
      __unsavedChanges = value;
      if ((unsavedChangesBarState?.target?.unsavedChanges ?? value) != value) {
        unsavedChangesBarState?.target?.setUnsavedChanges(value);
      }
    }
  }
  var current = WordPair.random();

  WeakReference<UnsavedChangesBarState>? unsavedChangesBarState;

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>{};

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  bool gridMode = true;
  
  late final ImageSyncManager imageSyncManager = ImageSyncManager(() => httpClient, () => imageSyncMode, () => builder?.currentTeam, () => locked);

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return "${directory.path}/the_purple_alliance";
  }

  Future<File> get _configFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/config.json');
  }

  Future<File> get _searchFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/search.json');
  }

  Future<File> get _dataFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/data.json');
  }

  Future<File> get _schemeFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/scheme.json');
  }
  
  Future<File> get _cachedServerMetaFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/server_meta.json');
  }

  Future<Object?> readJsonFile(Future<File> file) async {
    try {
      File f = await file;
      if (kDebugMode) {
        log("reading $f");
      }
      final contents = await f.readAsString();
      if (kDebugMode) {
        log("contents: $contents");
      }
      return await compute(jsonDecode, contents);
    } catch (e) {
      log('$e');
      return null;
    }
  }

  static Future<File?> writeJsonFile(FutureOr<File> file, Object? data) async {
//    print("start of write json file");
    try {
//      print("about to await file");
      final f = await file;
//      print("got file");
      String contents;
      if (data != null) {
        contents = jsonEncode(data);
      } else {
        contents = "";
      }
//      print("ready to write contents: $contents");
      return await f.writeAsString(contents);
    } catch (e) {
      log('Error in writeJsonFile: $e');
      return Future.value(file);
    }
  }

  Future<Map<String, dynamic>> readConfig() async {
    log("reading config...");
    var config = await readJsonFile(_configFile);
    if (config is Map<String, dynamic>) {
      return config;
    } else {
      return {};
    }
  }

  Future<File?> writeConfig(Map<String, dynamic> data) async {
/*    return await compute((List<dynamic> args) async {
      return await writeJsonFile(args[0], args[1]);
    }, [_configFile, data]);*/
    return await compute2(writeJsonFile, await _configFile, data);
//    return await writeJsonFile(_configFile, data);
  }

  Future<File?> saveConfig() async {
    return await writeConfig(_config).then(
        (v) {
          unsavedChanges = false;
          return v;
        }
    );
  }

  Map<String, dynamic> get _config {
    _localPath.then((v) {
      log(v);
    });
    return {
      "colorful_teams": colorfulTeams,
      "team_color_reminder": teamColorReminder,
      "team_color_blue": teamColorBlue,
      "sync_interval": syncInterval.name,
      "image_sync_mode": imageSyncMode.name,
      "connection": {
        "locked": locked,
        "team_number": locked ? _teamNumber ?? teamNumberInProgress : teamNumberInProgress,
        "url": locked ? serverUrl ?? serverUrlInProgress : serverUrlInProgress,
        "username": username,
        "password": __password,
      },
    };
  }

  _setConfig(Map<String, dynamic> jsonData) async {
    log("Hello");
    if (jsonData["colorful_teams"] is bool) {
      log("Reading colorful teams ${jsonData["colorful_teams"]}");
      colorfulTeams = jsonData["colorful_teams"];
    }
    if (jsonData["team_color_reminder"] is bool) {
      teamColorReminder = jsonData["team_color_reminder"];
    }
    if (jsonData["team_color_blue"] is bool) {
      teamColorBlue = jsonData["team_color_blue"];
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
        __password = connection["password"];
      }
      if (shouldConnect) {
        locked = false;
        log("Awaiting connection...");
        notifyListeners();
        await connect(reconnecting: true);
        log("Connected...");
      }
    }
    notifyListeners();
    unsavedChanges = false;
  }

  var locked = false;
  var __teamNumberInProgress = 1234;
  int get teamNumberInProgress => __teamNumberInProgress;
  set teamNumberInProgress(int value) {
    unsavedChanges = true;
    __teamNumberInProgress = value;
  }
  var __serverUrlInProgress = "example.com";
  String get serverUrlInProgress => __serverUrlInProgress;
  set serverUrlInProgress(String value) {
    unsavedChanges = true;
    __serverUrlInProgress = value;
  }
  int? _teamNumber;
  String? serverUrl;
  ScoutingBuilder? builder;

  String? _error;

  String _username = "";
  String get username => _username;
  set username(String value) {
    unsavedChanges = true;
    _username = value;
  }

  String __password = "";
  String get password => __password;
  set password(String value) {
    if (locked) {
      log("Attempted password set while locked!");
      return;
    }
    unsavedChanges = true;
    __password = value;
  }

  void notifySettingsUpdate() {
    notifyListeners();
  }

  SyncInterval _syncInterval = SyncInterval.manual;
  SyncInterval get syncInterval => _syncInterval;
  set syncInterval(SyncInterval value) {
    unsavedChanges = true;
    _syncInterval = value;
  }

  ImageSyncMode _imageSyncMode = ImageSyncMode.manual;
  ImageSyncMode get imageSyncMode => _imageSyncMode;
  set imageSyncMode(ImageSyncMode value) {
    unsavedChanges = true;
    _imageSyncMode = value;
  }

  bool _colorfulTeams = true;

  bool get colorfulTeams => _colorfulTeams;

  set colorfulTeams(bool value) {
    _colorfulTeams = value;
    notifyListeners();
    unsavedChanges = true;
  }

  bool _teamColorReminder = false;

  bool get teamColorReminder => _teamColorReminder;

  set teamColorReminder(bool value) {
    _teamColorReminder = value;
    notifyListeners();
    unsavedChanges = true;
  }

  bool _teamColorBlue = false; // whether the team color reminder is blue or red

  bool get teamColorBlue => _teamColorBlue;

  set teamColorBlue(bool value) {
    _teamColorBlue = value;
    notifyListeners();
    unsavedChanges = true;
  }

  bool _setTeamNumber(int teamNumber) {
    if (!locked) {
      _teamNumber = teamNumber;
      notifyListeners();
    }
    return true;
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

  Future<Map<String, Map<String, dynamic>>?> get _previousSearchConfigurations async {
    Map<String, Map<String, dynamic>> out = {};
    var previousData = await readJsonFile(_searchFile);
    if (previousData is Map<String, dynamic>) {
      for (var entry in previousData.entries) {
        if (entry.value is Map<String, dynamic>) {
          out[entry.key] = entry.value;
        }
      }
      return out;
    } else {
      return null;
    }
  }

  Future<File?> _setPreviousSearchConfigurations(Map<String, Map<String, dynamic>>? data) async {
    return await compute2(writeJsonFile, await _searchFile, data ?? {});
  }

  Future<Map<String, dynamic>?> get _previousData async {
    var previousData = await readJsonFile(_dataFile);
    if (previousData is Map<String, dynamic>) {
      return previousData;
    } else {
      return null;
    }
  }

  Future<File?> _setPreviousData(Map<String, dynamic>? data) async {
    return await compute2(writeJsonFile, await _dataFile, data ?? {});
  }

  Future<List<dynamic>?> get _cachedScheme async {
    var cachedScheme = await readJsonFile(_schemeFile);
    if (cachedScheme is List<dynamic>) {
      return cachedScheme;
    } else {
      return null;
    }
  }

  Future<File?> _setCachedScheme(List<dynamic>? data) async {
/*    return await compute((List<dynamic> args) async {
      return await writeJsonFile(args[0], args[1]);
    }, [_schemeFile, data]);*/
    return await compute2(writeJsonFile, await _schemeFile, data);
//    return await writeJsonFile(_schemeFile, data);
  }
  
  Future<File?> _setCachedServerMeta(Map<String, dynamic>? data) async {
/*    return await compute((List<dynamic> args) async {
      return await writeJsonFile(args[0], args[1]);
    }, [_cachedServerMetaFile, data]);*/
    return await compute2(writeJsonFile, await _cachedServerMetaFile, data);
//    return await writeJsonFile(_cachedServerMetaFile, data);
  }
  
  Future<Map<String, dynamic>?> get _cachedServerMeta async {
    var cachedServerMeta = await readJsonFile(_cachedServerMetaFile);
    if (cachedServerMeta is Map<String, dynamic>) {
      return cachedServerMeta;
    } else {
      return null;
    }
  }
  
  Future<Map<String, dynamic>> getServerMeta() async {
    return await compute(network.getServerMeta, httpClient);
  }

  Future<List<dynamic>> getScheme() async {
    log("Fetching scheme...");
    return await compute(network.getScheme, httpClient);
    /*return [
      {
        "type": "text",
        "label": "A cool label",
        "padding": 8.0
      },
      {
        "type": "text",
        "label": "Another cool label"
      },
      {
        "type": "text_field",
        "label": "A cool form entry",
        "key": "test"
      },
      {
        "type": "text",
        "label": "A totally different label",
        "padding": 20.0
      }
    ];*/
  }

  network.Connection get httpClient {
    return network.Connection(serverUrl ?? "https://example.com", username, password);
  }

  bool checkedCompetition = false; // keep track of whether we've checked what competition we are at yet. if we haven't checked yet, we don't want to send bad data.
  bool _currentlyChecking = false;

  Future<bool> checkCompetition() async {
    if (!locked) {
      return false;
    }
    if (checkedCompetition) {
      return true;
    }
    if (_currentlyChecking) {
      return checkedCompetition;
    }
    _currentlyChecking = true;
    if (await network.testAuthorizedConnection(httpClient)) {
      var cachedMeta = await _cachedServerMeta;
      var serverMeta = await getServerMeta();
      if (serverMeta["competition"] != cachedMeta?["competition"]) {
        log("Competition changed, clearing cache");
        var scheme = await getScheme();
        await _setCachedScheme(scheme);
        builder = safeLoadBuilder(scheme);
        await _setCachedServerMeta(serverMeta);
        await runSynchronization();
      }
      checkedCompetition = true;
    }
    _currentlyChecking = false;
    return checkedCompetition;
  }

  Future<void> clearAllData() async {
    while (_noSync || _currentlySaving) {
      await Future.delayed(const Duration(milliseconds: 100));
      log("Waiting for sync or save to be completed");
    }
    _noSync = true;
    _currentlySaving = true;
    builder = null;

    var scheme = await getScheme();
    _setCachedScheme(scheme);

    builder = safeLoadBuilder(scheme);
    builder?.setChangeNotifier(notifyListeners);
    _noSync = false;
    _currentlySaving = false;
    await runSynchronization();
  }

  Future<void> connect({bool reconnecting = false}) async {
    bool success1 = _setTeamNumber(teamNumberInProgress);
    bool success2 = _setServer(serverUrlInProgress);
    if (success1 && success2) {
      locked = true;
      log("Connecting with team_number: $_teamNumber, url: $serverUrl");
    } else {
      log("Failed to connect ($_error)");
      _teamNumber = null;
      serverUrl = null;
      notifyListeners();
      return;
    }
    bool serverFound = await compute(network.testUnauthorizedConnection, serverUrl ?? "https://example.com");
    if (!reconnecting) { // first time we connect, ensure we have a proper connection
      bool serverAuthorized = await compute(network.testAuthorizedConnection, httpClient);
      if (serverFound && serverAuthorized) {
        log("Server found and authorized");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Connected to server"),
        ));
      } else if (serverFound) {
        log("Server found but not authorized");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Invalid credentials"),
        ));
        locked = false;
        _teamNumber = null;
        serverUrl = null;
        notifyListeners();
        return;
      } else {
        log("Server not found");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Server not found"),
        ));
        locked = false;
        _teamNumber = null;
        serverUrl = null;
        notifyListeners();
        return;
      }
    }
    log("initializing connection");
    initializeBuilders();
    Map<String, dynamic>? cachedServerMeta = await _cachedServerMeta;
    Map<String, dynamic>? remoteServerMeta;
    if (serverFound) {
      remoteServerMeta = await getServerMeta();
      int myTeamNumber = _teamNumber ?? teamNumberInProgress;
      var remoteTeamNumber = remoteServerMeta.containsKey("team") ? remoteServerMeta["team"] : null;
      if (remoteTeamNumber != myTeamNumber || remoteTeamNumber == null) {
        remoteServerMeta = null;
        serverFound = false;
        locked = false;
        _teamNumber = null;
        serverUrl = null;
        notifyListeners();
        log("Remote team $remoteTeamNumber does not match $myTeamNumber");
        scaffoldKey.currentState?.clearSnackBars();
        scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: Text("Server team wrong ($remoteTeamNumber), expected $myTeamNumber"),
          action: remoteTeamNumber is int ? SnackBarAction(
            label: "Set",
            onPressed: () {
              teamNumberInProgress = remoteTeamNumber;
              notifyListeners();
            }
          ) : null,
        ));
        return;
      }
    }

    List<dynamic> scheme;
    if (reconnecting) {
      var cached = await _cachedScheme;
      if (cached != null) {
        bool needsNewScheme = true;
        if (!serverFound) { // if we haven't found the server, we can't get a new scheme - and server meta will be inaccurate anyway
          needsNewScheme = false;
        } else if (cachedServerMeta != null && cachedServerMeta.containsKey("scheme_version") && remoteServerMeta!.containsKey("scheme_version")) {
          needsNewScheme = remoteServerMeta["scheme_version"] != cachedServerMeta["scheme_version"];
        }
        if (needsNewScheme) {
          log("Scheme version mismatch, fetching new scheme...");
          scheme = await getScheme();
          _setCachedScheme(scheme);
        } else {
          scheme = cached;
        }
      } else {
        scheme = await getScheme();
        _setCachedScheme(scheme);
      }
    } else {
      scheme = await getScheme();
      _setCachedScheme(scheme);
    }
    builder = safeLoadBuilder(scheme);
    builder?.setChangeNotifier(notifyListeners);
    bool atDifferentCompetition = true;
    if (!serverFound) { // if we haven't found the server, we can't know if we're at a different competition - so don't clear stuff
      atDifferentCompetition = false;
    } else if (cachedServerMeta != null && cachedServerMeta.containsKey("competition") && remoteServerMeta!.containsKey("competition")) {
      atDifferentCompetition = remoteServerMeta["competition"] != cachedServerMeta["competition"];
      checkedCompetition = true;
    } else {
      checkedCompetition = true;
    }
    searchConfigurations = {};
    if (!atDifferentCompetition) {
      await _previousData.then((v) {
        if (v != null) {
          builder?.initializeValues(v.keys);
          builder?.allManagers.load(v, true);
        }
      });
      await _previousSearchConfigurations.then((v) {
        if (v != null) {
          searchConfigurations = v;
        }
      });
    } else {
      log("At different competition, clearing previous data...");
      imageSyncManager.clear(() => httpClient);
      await imageSyncManager.save();
    }
    if (checkedCompetition) {
      await _setCachedServerMeta(remoteServerMeta);
    }
    if (!reconnecting) {
      await saveConfig();
    }
    _startCompetitionCheckTimer();
    await runSynchronization();
    notifyListeners();
  }

  Future<void> unlock() async {
    teamNumberInProgress = _teamNumber ?? 1234;
    serverUrlInProgress = serverUrl ?? "example.com";
    Future<File?> future = _setPreviousData(builder?.allManagers.save())
        .then((_) async => await imageSyncManager.save())
        .then((_) async => await _setPreviousSearchConfigurations(searchConfigurations));
    builder = null;
    await future.then((_) {
      locked = false;
      notifyListeners();
    });
    await saveConfig();
    checkTimer?.cancel();
  }

  Future<void> reconnect() async {
    if (locked) {
      await unlock();
      await connect(reconnecting: true);
    }
  }

  int getDisplayTeamNumber() {
    return _teamNumber ?? teamNumberInProgress;
  }

  String getDisplayUrl() {
    return serverUrl ?? serverUrlInProgress;
  }

  int _minutesSinceLastSync = 0;
  bool _noSync = false;

  late Timer asyncTimer;

  bool _currentlySaving = false;
  late Timer autoSaveTimer;

  Timer? checkTimer;

  void _startCompetitionCheckTimer() {
    checkTimer?.cancel();
    _currentlyChecking = false;
    checkedCompetition = false;
    checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_currentlyChecking) {
        return;
      }
      if (await checkCompetition()) {
        timer.cancel();
      }
    });
  }

  Future<void> runSynchronization() async {
    if (_noSync) {
      log("Already synchronizing...");
      return;
    }
    if (builder == null) {
      log("No point in synchronizing non-existent data!");
      return;
    }
    if (!await checkCompetition()) {
      log("Connection not yet initialized, can't sync");
      return;
    }
    if (!await compute(network.testAuthorizedConnection, httpClient)) {
      log("Not authorized or not connected, can't sync");
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content: Text("Not authorized or not connected to server, can't sync"),
      ));
      return;
    }
    WordPair syncTrackingPair = WordPair.random();
    log("Synchronizing... !!! $_minutesSinceLastSync ${syncTrackingPair.asLowerCase}");
    _noSync = true;
    /*******************/
    /* Begin Protected */
    /*******************/
    try {
      await imageSyncManager.runMetaDownload(httpClient);
    } catch (e) {
      log("Error while synchronizing image meta: $e");
      scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: const Text("Error while synchronizing image meta"),
          action: SnackBarAction(
            label: "Info",
            onPressed: () {
              if (homepageContext == null) return;
              showDialog(
                context: homepageContext!,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Error while synchronizing image meta"),
                    content: Text('$e'),
                    actions: [
                      TextButton(
                        child: const Text("OK"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          )
      ));
    }
    try { //1234567890
      Map<String, dynamic> toServer = builder!.allManagers.saveNetworkDeltas();
//      await network.sendDeltas(httpClient, toServer);
      await compute2(network.sendDeltas, httpClient, toServer);
      Map<String, dynamic>? fromServer = await compute(network.getTeamData, httpClient);
      builder!.allManagers.load(fromServer, false);
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content: Text("Synced data with server"),
      ));
      log(syncTrackingPair.asLowerCase);
    } catch (e) {
      log("Error while synchronizing: $e");
      scaffoldKey.currentState?.showSnackBar(SnackBar(
        content: const Text("Error while synchronizing"),
        action: SnackBarAction(
          label: "Info",
          onPressed: () {
            if (homepageContext == null) return;
            showDialog(
              context: homepageContext!,
              builder: (context) {
                return AlertDialog(
                  title: const Text("Error while synchronizing"),
                  content: Text('$e'),
                  actions: [
                    TextButton(
                      child: const Text("OK"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        )
      ));
    }
    /*****************/
    /* End Protected */
    /*****************/
    _minutesSinceLastSync = 0;
    _noSync = false;
    notifyListeners();
  }

  Future<void> runSave({bool manual=false}) async {
    if (!_currentlySaving && builder != null) {
      while (_noSync) { // wait for sync to finish, to ensure that correct data is saved
        if (kDebugMode) {
          log("Waiting for end of sync...");
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      _noSync = true;
      _currentlySaving = true;
      await _setPreviousData(builder!.allManagers.save());
      await imageSyncManager.save();
      await _setPreviousSearchConfigurations(searchConfigurations);
      if (kDebugMode) {
        log("Saved...");
      }
      if (manual) {
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Saved!"),
        ));
      }
      _currentlySaving = false;
      _noSync = false;
    }
  }

  final GlobalKey<ScaffoldMessengerState> scaffoldKey;
  final GlobalKey<State<MainPage>> _homepageKey;
  BuildContext? get homepageContext => _homepageKey.currentContext;

  MyAppState(this.scaffoldKey, this._homepageKey) {
    _noSync = true;
    asyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      _minutesSinceLastSync++;
      if (!_noSync && _minutesSinceLastSync >= (_syncInterval.interval ?? _minutesSinceLastSync+1)) { //if the interval is null, it will not sync
        await runSynchronization();
      }
    });
    autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await runSave();
    });
    readConfig().then((v) async {
      log("Read config: $v");
      await _setConfig(v);
      imageSyncManager.load();
      log("Set.");
      _noSync = false;
    });
  }
}