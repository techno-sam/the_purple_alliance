import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:english_words/english_words.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:the_purple_alliance/data_manager.dart';
import 'package:the_purple_alliance/widgets.dart';
import 'package:the_purple_alliance/scouting_layout.dart';
import 'package:the_purple_alliance/network.dart' as network;

void main() {
  initializeBuilders();
  if (kDebugMode) {
    print("Enabling debug http overrides");
    HttpOverrides.global = network.DevHttpOverrides();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => MyAppState(_scaffoldKey),
        child: MaterialApp(
          scaffoldMessengerKey: _scaffoldKey,
          title: 'Namer App',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
            ),
          ),
          home: const MyHomePage(),
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
    __unsavedChanges = value;
    _unsavedChangesBarState?.target?.setState(() {
      _unsavedChangesBarState?.target?.unsavedChanges = value;
    });
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
    return File('$path/config.json');
  }

  Future<File> get _dataFile async {
    final path = await _localPath;
    return File('$path/data.json');
  }

  Future<File> get _schemeFile async {
    final path = await _localPath;
    return File('$path/scheme.json');
  }
  
  Future<File> get _cachedServerMetaFile async {
    final path = await _localPath;
    return File('$path/server_meta.json');
  }

  Future<Object?> readJsonFile(Future<File> file) async {
    try {
      File f = await file;
      print("reading $f");
      final contents = await f.readAsString();
      print("contents: $contents");
      return jsonDecode(contents);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<File?> writeJsonFile(Future<File> file, Object? data) async {
    try {
      final f = await file;
      String contents;
      if (data != null) {
        contents = jsonEncode(data);
      } else {
        contents = "";
      }
      return f.writeAsString(contents);
    } catch (e) {
      print(e);
      return Future.value(null);
    }
  }

  Future<Map<String, dynamic>> readConfig() async {
    print("reading config...");
    var config = await readJsonFile(_configFile);
    if (config is Map<String, dynamic>) {
      return config;
    } else {
      return {};
    }
  }

  Future<File?> writeConfig(Map<String, dynamic> data) async {
    return await writeJsonFile(_configFile, data);
  }

  Future<File?> saveConfig() {
    return writeConfig(_config).then(
        (v) {
          _unsavedChanges = false;
          return v;
        }
    );
  }

  Map<String, dynamic> get _config {
    _localPath.then((v) {
      print(v);
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
    print("Hello");
    if (jsonData["colorful_teams"] is bool) {
      print("Reading colorful teams ${jsonData["colorful_teams"]}");
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
        await connect(reconnecting: true);
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
      print("Attempted password set while locked!");
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
    return await writeJsonFile(_schemeFile, data);
  }
  
  Future<File?> _setCachedServerMeta(Map<String, dynamic>? data) async {
    return await writeJsonFile(_cachedServerMetaFile, data);
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
    print("Fetching scheme...");
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
        print("Competition changed, clearing cache");
        var scheme = await getScheme();
        await _setCachedScheme(scheme);
        builder = ExperimentBuilder.fromJson(scheme);
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
      print("Waiting for sync or save to be completed");
    }
    _noSync = true;
    _currentlySaving = true;
    builder = null;
    var scheme = await _cachedScheme;
    if (scheme == null) {
      scheme = await getScheme();
      _setCachedScheme(scheme);
    }
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
      print("Connecting with team_number: $_teamNumber, url: $_serverUrl");
    } else {
      print("Failed to connect ($_error)");
      _teamNumber = null;
      _serverUrl = null;
      notifyListeners();
      return;
    }
    bool serverFound = await network.testUnauthorizedConnection(_serverUrl ?? "https://example.com");
    if (!reconnecting) { // first time we connect, ensure we have a proper connection
      bool serverAuthorized = await network.testAuthorizedConnection(httpClient);
      if (serverFound && serverAuthorized) {
        print("Server found and authorized");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Connected to server"),
        ));
      } else if (serverFound) {
        print("Server found but not authorized");
        scaffoldKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Invalid credentials"),
        ));
        locked = false;
        _teamNumber = null;
        _serverUrl = null;
        notifyListeners();
        return;
      } else {
        print("Server not found");
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
    print("initializing connection");
    initializeBuilders();
    Map<String, dynamic>? cachedServerMeta = await _cachedServerMeta;
    Map<String, dynamic>? remoteServerMeta;
    if (serverFound) {
      remoteServerMeta = await getServerMeta();
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
          print("Scheme version mismatch, fetching new scheme...");
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
      print("At different competition, clearing previous data...");
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
      print("Already synchronizing...");
      return;
    }
    if (builder == null) {
      print("No point in synchronizing non-existent data!");
      return;
    }
    if (!await checkCompetition()) {
      print("Connection not yet initialized, can't sync");
      return;
    }
    if (!await network.testAuthorizedConnection(httpClient)) {
      print("Not authorized or not connected, can't sync");
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content: Text("Not authorized or not connected to server, can't sync"),
      ));
      return;
    }
    WordPair pair = WordPair.random();
    print("Synchronizing... !!! $_minutesSinceLastSync ${pair.asLowerCase}");
    _noSync = true;
    /*******************/
    /* Begin Protected */
    /*******************/
    try {
      Map<String, dynamic> toServer = builder!.teamManager.saveNetworkDeltas();
      await network.sendDeltas(httpClient, toServer);
      Map<String, dynamic>? fromServer = await network.getTeamData(httpClient);
      builder!.teamManager.load(fromServer, false);
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content: Text("Synced data with server"),
      ));
      print(pair.asLowerCase);
    } catch (e) {
      print("Error while synchronizing: $e");
      scaffoldKey.currentState?.showSnackBar(SnackBar(
        content: const Text("Error while synchronizing"),
        action: SnackBarAction(
          label: "Info",
          onPressed: () {
            showDialog(
              context: scaffoldKey.currentContext!,
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
        print("Waiting for end of sync...");
        await Future.delayed(const Duration(seconds: 1));
      }
      _noSync = true;
      _currentlySaving = true;
      await _setPreviousData(builder!.teamManager.save());
      print("Saved...");
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

  MyAppState(this.scaffoldKey) {
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
      print("Read config: $v");
      await _setConfig(v);
      print("Set.");
      _noSync = false;
    });
  }
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
    switch (selectedIndex) {
      case 0:
        page = const GeneratorPage();
        break;
      case 1:
        page = const FavoritesPage();
        break;
      case 2:
        page = TeamSelectionPage(() {
          setState(() {
            selectedIndex = 3;
          });
        });
        break;
      case 3:
        page = ExperimentsPage(() {
          setState(() {
            selectedIndex = 2;
          });
        }); //experiments
        break;
      case 4:
        page = SettingsPage(); //settings
        break;
      default:
        throw UnimplementedError("No widget for $selectedIndex");
    }
    return LayoutBuilder(
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
                      if (value == 5) {
                        appState.teamColorBlue = !appState.teamColorBlue;
                        await appState.saveConfig();
                      } else {
                        setState(() {
                          if (selectedIndex != value && selectedIndex == 4 && appState._unsavedChanges) { //if we're leaving the settings page, save the config
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
            floatingActionButton: Row(
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
    );
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

  TeamSelectionPage(this._viewTeam, {super.key});

  final void Function() _viewTeam;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "teamSelection");
  final GlobalKey<FormFieldState<String>> _entryKey = GlobalKey<FormFieldState<String>>(debugLabel: "teamSelectionEntry");

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
                                print('need to confirm team: ${_entryKey.currentState!.value}');
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
                                            print("Continuing with $teamNum");
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

  ExperimentsPage(
      this.goToTeamSelectionPage,
      {super.key}
      );

  final void Function() goToTeamSelectionPage;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buildExperiment(context, appState.builder, goToTeamSelectionPage)
        )
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "settings");

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
                IconButton(
                  onPressed: () async {
                    if (appState.locked) {
                      if (appState.builder != null) { //don't unlock if currently connecting - that would cause problems
                        await appState.unlock();
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
                                  decoration: InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: "Team Number",
                                    labelStyle: genericTextStyle,
                                  ),
                                  keyboardType: TextInputType.number,
                                  readOnly: appState.locked,
                                  initialValue: "${appState.getDisplayTeamNumber()}",
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
                                  decoration: InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: "Server",
                                    labelStyle: genericTextStyle,
                                  ),
                                  keyboardType: TextInputType.url,
                                  readOnly: appState.locked,
                                  initialValue: appState.getDisplayUrl(),
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
                                SimplePasswordFormField(genericTextStyle: genericTextStyle, appState: appState),
                              ]
                          )
                      )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConfigCard(
              theme: theme,
              label: "Username",
              onChanged: (value) {
                appState.username = value;
              },
              keyBoardType: TextInputType.name,
              initialValue: appState.username,
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
                          width: 200,
                          child: Text(
                            "Colorful Team Buttons",
                            style: genericTextStyle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                          width: 200,
                          child: Text(
                            "Team Color Reminder",
                            style: genericTextStyle.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                    backgroundColor: theme.colorScheme.primaryContainer,
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text("Force sync data - will clear all local data"),
                  )
                ),
              ],
            )
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
  });

  final TextStyle genericTextStyle;
  final MyAppState appState;

  @override
  State<SimplePasswordFormField> createState() => _SimplePasswordFormFieldState();
}

class _SimplePasswordFormFieldState extends State<SimplePasswordFormField> {

  bool passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
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
      obscureText: !passwordVisible,
      enableIMEPersonalizedLearning: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      readOnly: widget.appState.locked,
      initialValue: widget.appState._password,
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
              ElevatedButton.icon(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                      widget.theme.primaryColorLight),
                  visualDensity: VisualDensity.comfortable,
                ),
                onPressed: () {
                  appState.saveConfig();
                },
                label: Text(
                  "Save",
                  style: TextStyle(
                    color: widget.theme.primaryColorDark,
                  ),
                ),
                icon: Icon(
                  Icons.save_outlined,
                  color: widget.theme.primaryColorDark,
                ),
              ),
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
  });

  final ThemeData theme;
  final String label;
  final void Function(String) onChanged;
  final TextInputType? keyBoardType;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
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
