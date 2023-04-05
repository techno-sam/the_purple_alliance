import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:adaptive_navigation/adaptive_navigation.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:the_purple_alliance/widgets.dart';
import 'package:the_purple_alliance/scouting_layout.dart';
import 'package:the_purple_alliance/network.dart' as network;

Future<R> compute2<R, A, B>(FutureOr<R> Function(A, B) callback, A arg1, B arg2) async {
  //log("Compute2 with arg types: ${callback.runtimeType}, ${arg1.runtimeType}, ${arg2.runtimeType}");
  return await compute((List<dynamic> args) async {
    //print("before calling callback");
    return await callback(args[0], args[1]);
  }, [arg1, arg2]);
}

void main() {
  initializeBuilders();
  if (kDebugMode) {
    log("Enabling debug http overrides");
    HttpOverrides.global = network.DevHttpOverrides();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _homepageKey = GlobalKey<_MyHomePageState>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => MyAppState(_scaffoldKey, _homepageKey),
        child: MaterialApp(
          scaffoldMessengerKey: _scaffoldKey,
          title: 'The Purple Alliance',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
            ),
          ),
          home: MyHomePage(key: _homepageKey),
        )
    );
  }
}

/// Returns the problem with the url if there is one, or null if the url is OK
String? _verifyServerUrl(String url) {
  var tmp = Uri.tryParse(url);
  if (tmp == null) {
    return "Failed to parse url";
  }
  if (!tmp.isScheme("https")) { //just don't verify scheme temporarily
    return "Invalid scheme for server: ${tmp.scheme.isEmpty ? "[Blank]" : tmp.scheme}. Must be 'https'.";
  }
  return null;
}

class MyAppState extends ChangeNotifier {
  var __unsavedChanges = false;
  bool get _unsavedChanges => __unsavedChanges;
  set _unsavedChanges(bool value) {
    if (__unsavedChanges != value) {
      __unsavedChanges = value;
      _unsavedChangesBarState?.target?.setState(() {
        _unsavedChangesBarState?.target?.unsavedChanges = value;
      });
    }
  }
  var current = WordPair.random();

  WeakReference<_UnsavedChangesBarState>? _unsavedChangesBarState;

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

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return "${directory.path}/the_purple_alliance";
  }

  Future<File> get _configFile async {
    final path = await _localPath;
    await Directory(path).create(recursive: true);
    return File('$path/config.json');
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
          _unsavedChanges = false;
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
      "connection": {
        "locked": locked,
        "team_number": locked ? _teamNumber ?? _teamNumberInProgress : _teamNumberInProgress,
        "url": locked ? _serverUrl ?? _serverUrlInProgress : _serverUrlInProgress,
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
    if (jsonData["connection"] is Map) {
      var connection = jsonData["connection"];
      var shouldConnect = false;
      if (connection["locked"] is bool) {
        shouldConnect = connection["locked"];
      }
      if (connection["team_number"] is int) {
        _teamNumberInProgress = connection["team_number"];
      } else {
        shouldConnect = false;
      }
      if (connection["url"] is String) {
        _serverUrlInProgress = connection["url"];
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
    _unsavedChanges = false;
  }

  var locked = false;
  var __teamNumberInProgress = 1234;
  int get _teamNumberInProgress => __teamNumberInProgress;
  set _teamNumberInProgress(int value) {
    _unsavedChanges = true;
    __teamNumberInProgress = value;
  }
  var __serverUrlInProgress = "example.com";
  String get _serverUrlInProgress => __serverUrlInProgress;
  set _serverUrlInProgress(String value) {
    _unsavedChanges = true;
    __serverUrlInProgress = value;
  }
  int? _teamNumber;
  String? _serverUrl;
  ExperimentBuilder? builder;

  String? _error;

  String _username = "";
  String get username => _username;
  set username(String value) {
    _unsavedChanges = true;
    _username = value;
  }

  String __password = "";
  String get _password => __password;
  set _password(String value) {
    if (locked) {
      log("Attempted password set while locked!");
      return;
    }
    _unsavedChanges = true;
    __password = value;
  }

  SyncInterval _syncInterval = SyncInterval.manual;
  SyncInterval get syncInterval => _syncInterval;
  set syncInterval(SyncInterval value) {
    _unsavedChanges = true;
    _syncInterval = value;
  }

  bool _colorfulTeams = true;

  bool get colorfulTeams => _colorfulTeams;

  set colorfulTeams(bool value) {
    _colorfulTeams = value;
    notifyListeners();
    _unsavedChanges = true;
  }

  bool _teamColorReminder = false;

  bool get teamColorReminder => _teamColorReminder;

  set teamColorReminder(bool value) {
    _teamColorReminder = value;
    notifyListeners();
    _unsavedChanges = true;
  }

  bool _teamColorBlue = false; // whether the team color reminder is blue or red

  bool get teamColorBlue => _teamColorBlue;

  set teamColorBlue(bool value) {
    _teamColorBlue = value;
    notifyListeners();
    _unsavedChanges = true;
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
      _serverUrl = url;
      var error = _verifyServerUrl(url);
      if (error != null) {
        _error = error;
        _serverUrl = null;
        return false;
      }
      notifyListeners();
    }
    return true;
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
    return await writeJsonFile(_dataFile, data ?? {});
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
    return network.Connection(_serverUrl ?? "https://example.com", username, _password);
  }

  bool checkedCompetition = false; // keep track of whether we've checked what competition we are at yet. if we haven't checked yet, we don't want to send bad data.
  bool _currentlyChecking = false;

  Future<bool> checkCompetition() async {
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
    bool success1 = _setTeamNumber(_teamNumberInProgress);
    bool success2 = _setServer(_serverUrlInProgress);
    if (success1 && success2) {
      locked = true;
      log("Connecting with team_number: $_teamNumber, url: $_serverUrl");
    } else {
      log("Failed to connect ($_error)");
      _teamNumber = null;
      _serverUrl = null;
      notifyListeners();
      return;
    }
    bool serverFound = await compute(network.testUnauthorizedConnection, _serverUrl ?? "https://example.com");
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
        _serverUrl = null;
        notifyListeners();
        return;
      } else {
        log("Server not found");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Server not found"),
        ));
        locked = false;
        _teamNumber = null;
        _serverUrl = null;
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
      int myTeamNumber = _teamNumber ?? _teamNumberInProgress;
      var remoteTeamNumber = remoteServerMeta.containsKey("team") ? remoteServerMeta["team"] : null;
      if (remoteTeamNumber != myTeamNumber || remoteTeamNumber == null) {
        remoteServerMeta = null;
        serverFound = false;
        locked = false;
        _teamNumber = null;
        _serverUrl = null;
        notifyListeners();
        log("Remote team $remoteTeamNumber does not match $myTeamNumber");
        scaffoldKey.currentState?.clearSnackBars();
        scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: Text("Server team wrong ($remoteTeamNumber), expected $myTeamNumber"),
          action: remoteTeamNumber is int ? SnackBarAction(
            label: "Set",
            onPressed: () {
              _teamNumberInProgress = remoteTeamNumber;
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
    if (!atDifferentCompetition) {
      await _previousData.then((v) {
        if (v != null) {
          builder?.initializeValues(v.keys);
          builder?.teamManager.load(v, true);
        }
      });
    } else {
      log("At different competition, clearing previous data...");
    }
    if (checkedCompetition) {
      await _setCachedServerMeta(remoteServerMeta);
    }
    if (!reconnecting) {
      await saveConfig();
    }
    await runSynchronization();
    notifyListeners();
  }

  Future<void> unlock() async {
    _teamNumberInProgress = _teamNumber ?? 1234;
    _serverUrlInProgress = _serverUrl ?? "example.com";
    Future<File?> future = _setPreviousData(builder?.teamManager.save());
    builder = null;
    await future.then((_) {
      locked = false;
      notifyListeners();
    });
    await saveConfig();
  }

  Future<void> reconnect() async {
    if (locked) {
      await unlock();
      await connect(reconnecting: true);
    }
  }

  int getDisplayTeamNumber() {
    return _teamNumber ?? _teamNumberInProgress;
  }

  String getDisplayUrl() {
    return _serverUrl ?? _serverUrlInProgress;
  }

  int _minutesSinceLastSync = 0;
  bool _noSync = false;

  late Timer asyncTimer;

  bool _currentlySaving = false;
  late Timer autoSaveTimer;

  late Timer checkTimer;

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
    WordPair pair = WordPair.random();
    log("Synchronizing... !!! $_minutesSinceLastSync ${pair.asLowerCase}");
    _noSync = true;
    /*******************/
    /* Begin Protected */
    /*******************/
    try { //1234567890
      Map<String, dynamic> toServer = builder!.teamManager.saveNetworkDeltas();
//      await network.sendDeltas(httpClient, toServer);
      await compute2(network.sendDeltas, httpClient, toServer);
      Map<String, dynamic>? fromServer = await compute(network.getTeamData, httpClient);
      builder!.teamManager.load(fromServer, false);
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content: Text("Synced data with server"),
      ));
      log(pair.asLowerCase);
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
      await _setPreviousData(builder!.teamManager.save());
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
  final GlobalKey<_MyHomePageState> _homepageKey;
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
    checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_currentlyChecking) {
        return;
      }
      if (await checkCompetition()) {
        timer.cancel();
      }
    });
    readConfig().then((v) async {
      log("Read config: $v");
      await _setConfig(v);
      log("Set.");
      _noSync = false;
    });
  }
}

enum Pages {
//  generator(Icons.home, "Home"),
//  favorites(Icons.favorite, "Favorites"),
  teamSelection(Icons.list, "Teams"),
  editor(Icons.edit_note, "Editor"),
  settings(Icons.settings, "Settings"),
  ;
  final IconData icon;
  final String title;
  const Pages(this.icon, this.title);
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Widget page;
    Pages selectedPage = Pages.values[selectedIndex];
    switch (selectedPage) {
      /*case Pages.generator:
        page = const GeneratorPage();
        break;*/
      /*case Pages.favorites:
        page = const FavoritesPage();
        break;*/
      case Pages.teamSelection:
        page = TeamSelectionPage(() {
          setState(() {
            selectedIndex = Pages.editor.index;
          });
        });
        break;
      case Pages.editor:
        page = ExperimentsPage(() {
          setState(() {
            selectedIndex = Pages.teamSelection.index;
          });
        }); //experiments
        break;
      case Pages.settings:
        page = SettingsPage(); //settings
        break;
      default:
        throw UnimplementedError("No widget for $selectedIndex");
    }
    return GestureDetector(
      onTap: () {
        log("Tapped somewhere!");
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: ColorAdaptiveNavigationScaffold(
        body: Container(
          color: Theme
              .of(context)
              .colorScheme
              .primaryContainer,
          child: page,
        ),
        destinations: [
          for (Pages page in Pages.values)
            AdaptiveScaffoldDestination(title: page.title, icon: page.icon),
          if (appState.teamColorReminder)
            const AdaptiveScaffoldDestination(title: 'Switch Color', icon: Icons.invert_colors),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) async {
          if (value == Pages.values.length) { // last item isn't actually a page, but a selector
            appState.teamColorBlue = !appState.teamColorBlue;
            await appState.saveConfig();
          } else {
            setState(() {
              if (selectedIndex != value && selectedIndex == Pages.settings.index && appState._unsavedChanges) { //if we're leaving the settings page, save the config
                appState.saveConfig().then((_) {
                  setState(() {
                    selectedIndex = value;
                  });
                });
              } else {
                selectedIndex = value;
              }
            });
          }
        },
        fabInRail: false,
        navigationBackgroundColor: appState.teamColorReminder ? (appState.teamColorBlue ? Colors.blue.shade600 : Colors.red.shade600) : null,
        floatingActionButton: selectedPage == Pages.settings ? null : (getWindowType(context) >= AdaptiveWindowType.medium ? Row.new : Column.new)(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "runSync",
              onPressed: appState.runSynchronization,
              tooltip: "Synchronize data with server",
              child: const Icon(
                Icons.sync_alt,
              ),
            ),
            const SizedBox(width: 10, height: 10),
            FloatingActionButton(
              heroTag: "saveData",
              onPressed: () async {
                await appState.runSave(manual: true);
              },
              tooltip: "Save local data",
              child: const Icon(
                Icons.save_outlined,
              ),
            ),
          ],
        ),
      ),
    );
    /*return LayoutBuilder(
        builder: (context, constraints) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    backgroundColor: appState.teamColorReminder ? (appState.teamColorBlue ? Colors.blue.shade600 : Colors.red.shade600) : null,
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.favorite),
                        label: Text('Favorites'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.list),
                        label: Text('Teams'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.local_fire_department),
                        label: Text('Experiments'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                      if (appState.teamColorReminder)
                        const NavigationRailDestination(
                            icon: Icon(Icons.invert_colors),
                            label: Text('Switch color')
                        ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) async {
                      if (value == Pages.values.length) { // last item isn't actually a page, but a selector
                        appState.teamColorBlue = !appState.teamColorBlue;
                        await appState.saveConfig();
                      } else {
                        setState(() {
                          if (selectedIndex != value && selectedIndex == Pages.settings.index && appState._unsavedChanges) { //if we're leaving the settings page, save the config
                            appState.saveConfig().then((_) {
                              setState(() {
                                selectedIndex = value;
                              });
                            });
                          } else {
                            selectedIndex = value;
                          }
                        });
                      }
                    },
                  ),
                ), /*
              SizedBox(
                width: 15,
                child: Container(
                  color: Colors.red,
                ),
              ),// */
                Expanded(
                  child: Container(
                    color: Theme
                        .of(context)
                        .colorScheme
                        .primaryContainer,
                    child: page,
                  ),
                ),
              ],
            ),
            // if we are on the settings page, don't display the floating buttons
            floatingActionButton: selectedPage == Pages.settings ? null : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: appState.runSynchronization,
                  tooltip: "Synchronize data with server",
                  child: const Icon(
                    Icons.sync_alt,
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: () async {
                    await appState.runSave(manual: true);
                  },
                  tooltip: "Save local data",
                  child: const Icon(
                    Icons.save_outlined,
                  ),
                ),
              ],
            ),
          );
        }
    );*/
  }
}

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: const Text('Like'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return const Center(
          child: Text('No favorites yet.')
      );
    } else {
      final theme = Theme.of(context);
      return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('You have '
                  '${appState.favorites.length} favorite${appState.favorites.length!=1 ? 's' : ''}:'),
            ),
            for (var favorite in appState.favorites)
              ListTile(
                title: Text(favorite.asLowerCase),
                leading: const Icon(Icons.favorite),
                iconColor: theme.primaryColor,
              )
          ]
      );
    }
  }
}

class TeamTile extends StatelessWidget {
  final int teamNo;
  final void Function() _viewTeam;

  const TeamTile(
      this.teamNo,
      this._viewTeam,
      {super.key}
      );

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appState = context.watch<MyAppState>();
    final Color color = appState.colorfulTeams ? Colors.primaries[teamNo % Colors.primaries.length] : theme.colorScheme.tertiaryContainer;
    return Card(
      elevation: 5,
      color: color,
      child: InkWell(
        onTap: () async {
          appState.builder?.setTeam(teamNo);
          await Future.delayed(const Duration(milliseconds: 250));
          _viewTeam();
        },
        splashColor: appState.colorfulTeams ? Color.fromARGB(255, 255-color.red, 255-color.green, 255-color.blue) : null,
        customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
        child: Center(child: Text(
          "$teamNo",
          style: const TextStyle(
            fontSize: 20,
          )
        )),
      ),
    );
  }
}

class TeamSelectionPage extends StatelessWidget {

  const TeamSelectionPage(this._viewTeam, {super.key});

  final void Function() _viewTeam;

  static final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "teamSelection");
  static final GlobalKey<FormFieldState<String>> _entryKey = GlobalKey<FormFieldState<String>>(debugLabel: "teamSelectionEntry");

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    List<int> teams = appState.builder?.teamManager.managers.keys.toList() ?? [];
    teams.sort();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) => TeamTile(teams[index], _viewTeam),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 128,
                childAspectRatio: 2.0,
              ),
            ),
          ),
          if (appState.builder != null)
            Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: _formKey,
              child: Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          key: _entryKey,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            labelText: "Add Team",
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: "",
                          /*onChanged: (value) {
                            var number = int.tryParse(value);
  //                          if (number != null) {
  //
  //                          }
                          },*/
                          validator: (String? value) {
                            if (value == null) {
                              return "Value must be a number";
                            }
                            var num = int.tryParse(value);
                            if (num == null) {
                              return "Value must be a number";
                            }
                            if (num < 1) {
                              return "Invalid team number";
                            }
                            if (num > 9999) {
                              return "Invalid team number";
                            }
                            if (teams.contains(num)) {
                              return "Already added";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () {
                          if (_formKey.currentState != null && _formKey.currentState!.validate() && _entryKey.currentState != null) {
                            var value = _entryKey.currentState!.value;
                            if (value != null) {
                              var teamNum = int.tryParse(value);
                              if (teamNum != null && !teams.contains(teamNum)) {
                                log('need to confirm team: ${_entryKey.currentState!.value}');
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text("Confirm team"),
                                      content: Text("Do you want to add team $teamNum?\nThis cannot be undone."),
                                      actions: [
                                        TextButton(
                                          child: const Text("Cancel"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _entryKey.currentState!.reset();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text("Continue"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _entryKey.currentState!.reset();
                                            log("Continuing with $teamNum");
                                            appState.builder?.initializeTeam(teamNum);
                                            appState.notifyListeners();
                                          }
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            }
                          }
                        },
                        tooltip: "Add",
                        icon: const Icon(Icons.add_circle, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ExperimentsPage extends StatelessWidget {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "scouting");
  static final GlobalKey _scrollKey = GlobalKey(debugLabel: "scroll");

  ExperimentsPage(
      this.goToTeamSelectionPage,
      {super.key}
      );

  final void Function() goToTeamSelectionPage;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var children = buildExperiment(context, appState.builder, goToTeamSelectionPage);
    return Form(
      key: _formKey,
      child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: children.length <= 1
              ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
          )
              : SingleChildScrollView(
            key: _scrollKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
      ),
    );
  }
}

bool _isQRScanningSupported() {
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

class SettingsPage extends StatelessWidget {

  static final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "settings");
  static final GlobalKey<FormFieldState<String>> _teamNumberKey = GlobalKey<FormFieldState<String>>(debugLabel: "teamNumber");
  static final GlobalKey<FormFieldState<String>> _serverKey = GlobalKey<FormFieldState<String>>(debugLabel: "serverUrl");
  static final GlobalKey<FormFieldState<String>> _passwordKey = GlobalKey<FormFieldState<String>>(debugLabel: "password");
  static final GlobalKey<FormFieldState<String>> _usernameKey = GlobalKey<FormFieldState<String>>(debugLabel: "username");

  final MobileScannerController _cameraController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    var genericTextStyle = TextStyle(color: theme.colorScheme.onPrimaryContainer);
    var buttonColor = (appState.locked && appState.builder == null) ? const Color.fromARGB(0, 0, 0, 0) : null;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          children: [
            UnsavedChangesBar(theme: theme, initialValue: () => appState._unsavedChanges),
            Row(
              children: [
                Column(
                  children: [
                    if (appState.locked)
                      IconButton(
                        onPressed: () async {
                          await appState.reconnect();
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: "Refresh scheme",
                      ),
                    IconButton(
                      onPressed: () async {
                        if (appState.locked) {
                          if (appState.builder != null) { //don't unlock if currently connecting - that could cause problems
                            await appState.unlock();
                          } else {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("Connecting"),
                                  content: const Text("Disconnecting while connecting can cause issues. Are you sure you want to disconnect?"),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: const Text("Disconnect"),
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        await appState.unlock();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        } else if (_formKey.currentState!.validate()) {
                          await appState.connect();
                        }
                      },
                      highlightColor: buttonColor,
                      hoverColor: buttonColor,
                      focusColor: buttonColor,
                      icon: Icon(
                        appState.locked ? Icons.lock_outlined : Icons.wifi,
                        color: appState.locked ? (appState.builder == null ? Colors.amber : Colors.red) : Colors.green,
                      ),
                      tooltip: appState.locked
                          ? (appState.builder == null ? "Connecting" : "Unlock connection settings")
                          : "Connect",
                    ),
                    if (appState.locked || _isQRScanningSupported())
                      IconButton(
                        onPressed: () {
                          const identifier = "com.team1661.the_purple_alliance";
                          if (appState.locked) { //provide connection data
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: ((context) {
                                    return Scaffold(
                                      appBar: AppBar(
                                        title: const Text("Connection Data"),
                                        centerTitle: true,
                                      ),
                                      body: Center(
                                        child: QrImage(
                                          data: jsonEncode({
                                            "identifier": identifier,
                                            "team_number": appState.getDisplayTeamNumber(),
                                            "server": appState._serverUrl,
                                            "password": appState._password,
                                          }),
                                          size: 280,
                                        ),
                                      ),
                                    );
                                  }),
                                )
                            );
                          } else if (_isQRScanningSupported()) { //read connection data
                            try {
                              var alreadyGot = false; //prevent multiple handling of a qr code, which crashes Navigator
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: ((context) {
                                    return Scaffold(
                                      appBar: AppBar(
                                        title: const Text("Scan"),
                                        actions: [
                                          IconButton(
                                            color: Colors.white,
                                            icon: ValueListenableBuilder(
                                              valueListenable: _cameraController.torchState,
                                              builder: (context, state, child) {
                                                switch (state) {
                                                  case TorchState.off:
                                                    return const Icon(Icons.flash_off, color: Colors.grey);
                                                  case TorchState.on:
                                                    return const Icon(Icons.flash_on, color: Colors.yellow);
                                                }
                                              },
                                            ),
                                            iconSize: 32.0,
                                            onPressed: () => _cameraController.toggleTorch(),
                                          ),
                                          IconButton(
                                            color: Colors.white,
                                            icon: ValueListenableBuilder(
                                              valueListenable: _cameraController.cameraFacingState,
                                              builder: (context, state, child) {
                                                switch (state) {
                                                  case CameraFacing.front:
                                                    return const Icon(Icons.camera_front, color: Colors.blue);
                                                  case CameraFacing.back:
                                                    return const Icon(Icons.camera_rear, color: Colors.blue);
                                                }
                                              },
                                            ),
                                            iconSize: 32.0,
                                            onPressed: () => _cameraController.switchCamera(),
                                          ),
                                        ],
                                      ),
                                      body: MobileScanner(
                                        controller: _cameraController,
                                        onDetect: (capture) async {
                                          final List<Barcode> barcodes = capture.barcodes;
                                          log("barcodes: $barcodes");
                                          for (final barcode in barcodes) {
                                            if (alreadyGot) break;
                                            if (barcode.format == BarcodeFormat.qrCode) {
                                              var value = barcode.rawValue;
                                              log("Found barcode: $value");
                                              if (value != null) {
                                                try {
                                                  var decoded = jsonDecode(value);
                                                  if (decoded is Map<String, dynamic> && decoded.containsKey("identifier") &&
                                                      decoded["identifier"] == identifier && decoded["team_number"] is int &&
                                                      decoded["server"] is String && decoded["password"] is String) {
                                                    appState._teamNumberInProgress = decoded["team_number"];
                                                    appState._serverUrlInProgress = decoded["server"];
                                                    appState._password = decoded["password"];
                                                    log("Decoded number: ${appState._teamNumberInProgress}");
                                                    appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text("Obtained connection data")));
                                                    log("Connection data got!");
                                                    alreadyGot = true;
                                                    appState.notifyListeners();
                                                    Navigator.pop(context);
                                                    break;
                                                  }
                                                } catch (e) {
                                                  // pass
                                                }
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  }),
                                ),
                              );
                            } on MissingPluginException {
                              appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(
                                content: Text("QR Scanning is not supported on your platform"),
                              ));
                            }
                          } else {
                            appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(
                              content: Text("QR Scanning is not supported on your platform"),
                            ));
                          }
                        },
                        icon: Icon(
                          appState.locked ? Icons.qr_code : Icons.qr_code_scanner,
                        ),
                        tooltip: appState.locked ? "Show QR code" : "Scan QR code",
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                      color: appState.locked ? theme.colorScheme
                          .tertiaryContainer : theme.colorScheme
                          .primaryContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                              children: [
                                TextFormField(
                                  key: _teamNumberKey,
                                  decoration: InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: "Team Number",
                                    labelStyle: genericTextStyle,
                                  ),
                                  controller: TextEditingController(text: "${appState.getDisplayTeamNumber()}"),
                                  keyboardType: TextInputType.number,
                                  readOnly: appState.locked,
//                                  initialValue: "${appState.getDisplayTeamNumber()}",
                                  onChanged: (value) {
                                    var number = int.tryParse(value);
                                    if (number != null) {
                                      appState._teamNumberInProgress = number;
                                    }
                                  },
                                  validator: (String? value) {
                                    if (value == null || int.tryParse(value) == null) {
                                      return "Value must be a number";
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  key: _serverKey,
                                  decoration: InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: "Server",
                                    labelStyle: genericTextStyle,
                                  ),
                                  controller: TextEditingController(text: appState.getDisplayUrl()),
                                  keyboardType: TextInputType.url,
                                  readOnly: appState.locked,
//                                  initialValue: appState.getDisplayUrl(),
                                  onChanged: (value) {
                                    appState._serverUrlInProgress = value;
                                  },
                                  validator: (String? value) {
                                    if (value == null || value == "") {
                                      return "Must have a url!";
                                    }
                                    return _verifyServerUrl(value);
                                  },
                                ),
                                TextFormField(
                                  key: _usernameKey,
                                  decoration: InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: "Name",
                                    labelStyle: genericTextStyle,
                                  ),
                                  controller: TextEditingController(text: appState.username),
                                  keyboardType: TextInputType.name,
                                  readOnly: appState.locked,
                                  onChanged: (value) {
                                    appState.username = value;
                                  },
                                  validator: (String? value) {
                                    if (value == null || value == "") {
                                      return "Must have a name set";
                                    }
                                    return null;
                                  },
                                ),
                                SimplePasswordFormField(formKey: _passwordKey, genericTextStyle: genericTextStyle, appState: appState),
                              ]
                          )
                      )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sync interval",
                      style: genericTextStyle,
                    ),
                    SyncTimeSelector(theme: theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            "Colorful Team Buttons",
                            style: genericTextStyle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
//                        const SizedBox(width: 2),
                        Switch(
                          value: appState.colorfulTeams,
                          onChanged: (value) {
                            appState.colorfulTeams = value;
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            "Team Color Reminder",
                            style: genericTextStyle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
//                        const SizedBox(width: 2),
                        Switch(
                          value: appState.teamColorReminder,
                          onChanged: (value) {
                            appState.teamColorReminder = value;
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Clear all local data?"),
                          content: const Text("This will clear all local data, and force a sync with the server."),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await appState.clearAllData();
                              },
                              child: const Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.warning,
                          color: Colors.black,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Force sync data\n(Will clear all local data)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class SimplePasswordFormField extends StatefulWidget {
  const SimplePasswordFormField({
    super.key,
    required this.genericTextStyle,
    required this.appState,
    this.formKey,
  });

  final TextStyle genericTextStyle;
  final MyAppState appState;
  final Key? formKey;

  @override
  State<SimplePasswordFormField> createState() => _SimplePasswordFormFieldState();
}

class _SimplePasswordFormFieldState extends State<SimplePasswordFormField> {

  bool passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      key: widget.formKey,
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        labelText: "Password",
        labelStyle: widget.genericTextStyle,
        suffixIcon: IconButton(
          icon: Icon(
            passwordVisible ? Icons.visibility : Icons.visibility_off,
            color: theme.colorScheme.primary,
          ),
          onPressed: () {
            setState(() {
              passwordVisible = !passwordVisible;
            });
          },
        ),
      ),
      controller: TextEditingController(text: widget.appState._password),
      obscureText: !passwordVisible,
      enableIMEPersonalizedLearning: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      readOnly: widget.appState.locked,
//      initialValue: widget.appState._password,
      onChanged: (value) {
        widget.appState._password = value;
      },
      validator: (String? value) {
        if (value == null || value == "") {
          return "Must have a password!";
        }
        return null; // ok
      },
    );
  }
}

class UnsavedChangesBar extends StatefulWidget {
  const UnsavedChangesBar({
    super.key,
    required this.theme,
    required this.initialValue,
  });

  final ThemeData theme;
  final bool Function() initialValue;

  @override
  State<UnsavedChangesBar> createState() => _UnsavedChangesBarState(initialValue());
}

class _UnsavedChangesBarState extends State<UnsavedChangesBar> {

  _UnsavedChangesBarState(this.unsavedChanges);

  bool unsavedChanges;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    appState._unsavedChangesBarState = WeakReference(this);
    return unsavedChanges ? Card(
        color: widget.theme.colorScheme.error,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: widget.theme.colorScheme.onError),
              const SizedBox(width: 10),
              Text(
                "Unsaved changes...",
                style: TextStyle(
                  color: widget.theme.colorScheme.onError,
                ),
              ),
              const Expanded(child: SizedBox()),
              IconButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(widget.theme.primaryColorLight),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await appState.saveConfig();
                  print("happy with result");
                },
                icon: Icon(
                  Icons.save_outlined,
                  color: widget.theme.primaryColorDark,
                ),
              ),
/*              ElevatedButton.icon(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                      widget.theme.primaryColorLight),
                  visualDensity: VisualDensity.comfortable,
                ),
                onPressed: () {
                  appState.saveConfig();
                },
                label: LayoutBuilder(
                  builder: (context, constraints) {
                    return Text(
                      "",//constraints.maxWidth > 1900 ? "Save" : "",
                      style: TextStyle(
                        color: widget.theme.primaryColorDark,
                      ),
                    );
                  }
                ),
                icon: Icon(
                  Icons.save_outlined,
                  color: widget.theme.primaryColorDark,
                ),
              ),*/
            ],
          ),
        )
    ) : const SizedBox();
  }
}

class ConfigCard extends StatelessWidget {
  const ConfigCard({
    super.key,
    required this.theme,
    required this.label,
    required this.onChanged,
    this.keyBoardType,
    this.initialValue,
    this.formKey,
  });

  final ThemeData theme;
  final String label;
  final void Function(String) onChanged;
  final TextInputType? keyBoardType;
  final String? initialValue;
  final Key? formKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            key: formKey,
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              labelText: label,
              labelStyle: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            keyboardType: keyBoardType,
            onChanged: onChanged,
            initialValue: initialValue,
          )
      ),
    );
  }
}


class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}
