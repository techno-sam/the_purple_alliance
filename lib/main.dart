import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:the_purple_alliance/data_manager.dart';
import 'package:the_purple_alliance/widgets.dart';
import 'package:the_purple_alliance/scouting_layout.dart';

void main() {
  initializeBuilders();
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
          home: MyHomePage(),
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
  if (tmp.scheme != "" && !tmp.isScheme("https")) {
    return "Invalid scheme for server: ${tmp.scheme}";
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
      if (shouldConnect) {
        locked = false;
        await connect(reconnecting: true);
        locked = true;
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

  Future<List<dynamic>> getScheme() async {
    print("Fetching scheme...");
    return [
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
    ];
  }

  Future<void> connect({bool reconnecting = false}) async {
    bool success1 = _setTeamNumber(_teamNumberInProgress);
    bool success2 = _setServer(_serverUrlInProgress);
    if (success1 && success2) {
      locked = true;
      print("Connected with team_number: $_teamNumber, url: $_serverUrl");
    } else {
      print("Failed to connect ($_error)");
      _teamNumber = null;
      _serverUrl = null;
    }
    initializeBuilders();
    List<dynamic> scheme;
    if (reconnecting) {
      var cached = await _cachedScheme;
      if (cached != null) {
        scheme = cached;
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
    await _previousData.then((v) {
      if (v != null) {
        builder?.initializeValues(v.keys);
        builder?.teamManager.load(v, true);
      }
    });
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
    await saveConfig();
    await future.then((_) {
      locked = false;
      notifyListeners();
    });
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

  Future<void> runSynchronization() async {
    if (_noSync) {
      print("Already synchronizing...");
      return;
    }
    WordPair pair = WordPair.random();
    print("Synchronizing... !!! ${_minutesSinceLastSync} ${pair.asLowerCase}");
    _noSync = true;
    await Future.delayed(const Duration(seconds: 2), () {
      print(pair.asLowerCase);
    });
    scaffoldKey.currentState?.showSnackBar(const SnackBar(
      content: Text("Synced data with server"),
    ));
    _minutesSinceLastSync = 0;
    _noSync = false;
  }

  final GlobalKey<ScaffoldMessengerState> scaffoldKey;

  MyAppState(this.scaffoldKey) {
    asyncTimer = Timer.periodic(Duration(seconds: 1), (timer) async { //FIXME: change delay to minutes, not seconds
      _minutesSinceLastSync++;
      if (!_noSync && _minutesSinceLastSync >= (_syncInterval.interval ?? _minutesSinceLastSync+1)) { //if the interval is null, it will not sync
        await runSynchronization();
      }
    });
    autoSaveTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_currentlySaving && builder != null) {
        while (_noSync) { // wait for sync to finish, to ensure that correct data is saved
          print("Waiting for end of sync...");
          await Future.delayed(const Duration(seconds: 1));
        }
        _noSync = true;
        _currentlySaving = true;
        await _setPreviousData(builder!.teamManager.save());
        print("Saved...");
        /*scaffoldKey.currentState?.showSnackBar(SnackBar(
          content: const Text("Saved!"),
        ));*/
        _currentlySaving = false;
        _noSync = false;
      }
    });
    readConfig().then((v) async {
      print("Read config: $v");
      await _setConfig(v);
      print("Set.");
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
        page = ExperimentsPage(); //experiments
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
                    onDestinationSelected: (value) {
                      setState(() {
                        if (value == 5) {
                          appState.teamColorBlue = !appState.teamColorBlue;
                        } else {
                          if (selectedIndex != value && selectedIndex == 4 && appState._unsavedChanges) { //if we're leaving the settings page, save the config
                            appState.saveConfig().then((_) {
                              setState(() {
                                selectedIndex = value;
                              });
                            });
                          } else {
                            selectedIndex = value;
                          }
                        }
                      });
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
            floatingActionButton: FloatingActionButton(
                onPressed: appState.runSynchronization,
                child: const Icon(
                  Icons.sync_alt,
                )
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
        onTap: () {
          appState.builder?.setTeam(teamNo);
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

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    List<int> teams = appState.builder?.teamManager.managers.keys.toList() ?? [];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            itemCount: teams.length,
            itemBuilder: (context, index) => TeamTile(teams[index], _viewTeam),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 128,
              childAspectRatio: 2.0,
            ),
          );
        }
      )
    );
  }
}

class ExperimentsPage extends StatelessWidget {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "scouting");

  ExperimentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buildExperiment(context, appState.builder)
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
                      await appState.unlock();
                    } else if (_formKey.currentState!.validate()) {
                      await appState.connect();
                    }
                  },
                  icon: Icon(
                    appState.locked ? Icons.lock_outlined : Icons.wifi,
                    color: appState.locked ? Colors.red : Colors.green,
                  ),
                  tooltip: appState.locked
                      ? "Unlocking will clear all stored data."
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
                if (value == "test_set") {
                  print("yaya!");
                  var text_value = appState.builder?.manager?.values["test"];
                  print(appState.builder?.manager?.values);
                  print(text_value);
                  if (text_value is TextDataValue) {
                    text_value.value = "never gonna give you up, never gonna let you down,";
                    text_value.changeNotifier();
                  }
                }
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
          ],
        ),
      ),
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
