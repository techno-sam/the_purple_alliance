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
import 'package:the_purple_alliance/state/meta/config_state.dart';
import 'package:the_purple_alliance/widgets/scouting/scouting_layout.dart';
import 'package:the_purple_alliance/state/network.dart' as network;
import 'package:the_purple_alliance/utils/util.dart';



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
          child: ChangeNotifierProvider(
            create: (context) => Provider.of<MyAppState>(context, listen: false).config,
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
          ),
        )
    );
  }
}


Future<String> get localPath async {
  final directory = await getApplicationDocumentsDirectory();

  return "${directory.path}/the_purple_alliance";
}



Future<File> get _searchFile async {
  final path = await localPath;
  await Directory(path).create(recursive: true);
  return File('$path/search.json');
}

Future<File> get _dataFile async {
  final path = await localPath;
  await Directory(path).create(recursive: true);
  return File('$path/data.json');
}

Future<File> get _schemeFile async {
  final path = await localPath;
  await Directory(path).create(recursive: true);
  return File('$path/scheme.json');
}

Future<File> get _cachedServerMetaFile async {
  final path = await localPath;
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

Future<File?> writeJsonFile(FutureOr<File> file, Object? data) async {
  try {
    final f = await file;
    String contents;
    if (data != null) {
      contents = jsonEncode(data);
    } else {
      contents = "";
    }
    return await f.writeAsString(contents);
  } catch (e) {
    log('Error in writeJsonFile: $e');
    return Future.value(file);
  }
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
  return await compute2(writeJsonFile, await _schemeFile, data);
}

Future<File?> _setCachedServerMeta(Map<String, dynamic>? data) async {
  return await compute2(writeJsonFile, await _cachedServerMetaFile, data);
}

Future<Map<String, dynamic>?> get _cachedServerMeta async {
  var cachedServerMeta = await readJsonFile(_cachedServerMetaFile);
  if (cachedServerMeta is Map<String, dynamic>) {
    return cachedServerMeta;
  } else {
    return null;
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

  bool gridMode = true;

  final Object _configPrivateKey = Object();
  late final ImageSyncManager imageSyncManager = ImageSyncManager(() => httpClient, () => config.imageSyncMode, () => builder?.currentTeam, () => config.locked);
  late final ConfigState config = ConfigState(reconnectCallback: () async {
    await connect(reconnecting: true);
  }, privateKey: _configPrivateKey);
  
  ScoutingBuilder? builder;


  void notifySettingsUpdate() {
    config.notifyListeners();
  }
  
  
  Future<Map<String, dynamic>> getServerMeta() async {
    return await compute(network.getServerMeta, httpClient);
  }

  Future<List<dynamic>> getScheme() async {
    log("Fetching scheme...");
    return await compute(network.getScheme, httpClient);
  }

  network.Connection get httpClient {
    return network.Connection(config.serverUrl ?? "https://example.com", config.username, config.password);
  }

  bool checkedCompetition = false; // keep track of whether we've checked what competition we are at yet. if we haven't checked yet, we don't want to send bad data.
  bool _currentlyChecking = false;

  Future<bool> checkCompetition() async {
    if (!config.locked) {
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
    bool success1 = config.setTeamNumber(config.teamNumberInProgress, _configPrivateKey);
    bool success2 = config.setServer(config.serverUrlInProgress, _configPrivateKey);
    if (success1 && success2) {
      config.locked = true;
      log("Connecting with team_number: ${config.teamNumber}, url: ${config.serverUrl}");
    } else {
      log("Failed to connect (${config.error})");
      config.setConnectionFailed(_configPrivateKey);
      notifyListeners();
      return;
    }
    bool serverFound = await compute(network.testUnauthorizedConnection, config.serverUrl ?? "https://example.com");
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
        config.locked = false;
        config.setConnectionFailed(_configPrivateKey);
        notifyListeners();
        return;
      } else {
        log("Server not found");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Server not found"),
        ));
        config.locked = false;
        config.setConnectionFailed(_configPrivateKey);
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
      int myTeamNumber = config.getDisplayTeamNumber();
      var remoteTeamNumber = remoteServerMeta.containsKey("team") ? remoteServerMeta["team"] : null;
      if (remoteTeamNumber != myTeamNumber || remoteTeamNumber == null) {
        remoteServerMeta = null;
        serverFound = false;
        config.locked = false;
        config.setConnectionFailed(_configPrivateKey);
        notifyListeners();
        log("Remote team $remoteTeamNumber does not match $myTeamNumber");
        scaffoldKey.currentState?.clearSnackBars();
        scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: Text("Server team wrong ($remoteTeamNumber), expected $myTeamNumber"),
          action: remoteTeamNumber is int ? SnackBarAction(
            label: "Set",
            onPressed: () {
              config.teamNumberInProgress = remoteTeamNumber;
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
      await config.saveConfig();
    }
    _startCompetitionCheckTimer();
    await runSynchronization();
    notifyListeners();
  }

  Future<void> unlock() async {
    config.teamNumberInProgress = config.teamNumber ?? 1234;
    config.serverUrlInProgress = config.serverUrl ?? "example.com";
    Future<File?> future = _setPreviousData(builder?.allManagers.save())
        .then((_) async => await imageSyncManager.save())
        .then((_) async => await _setPreviousSearchConfigurations(searchConfigurations));
    builder = null;
    await future.then((_) {
      config.locked = false;
      notifyListeners();
    });
    await config.saveConfig();
    checkTimer?.cancel();
  }

  Future<void> reconnect() async {
    if (config.locked) {
      await unlock();
      await connect(reconnecting: true);
    }
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
      if (!_noSync && _minutesSinceLastSync >= (config.syncInterval.interval ?? _minutesSinceLastSync+1)) { //if the interval is null, it will not sync
        await runSynchronization();
      }
    });
    autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await runSave();
    });
    config.readConfig(_configPrivateKey).then((_) async {
      imageSyncManager.load();
      log("Set.");
      _noSync = false;
    });
  }
}