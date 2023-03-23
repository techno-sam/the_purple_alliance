import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'scouting_layout.dart';

void main() {
  initializeBuilders();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => MyAppState(),
        child: MaterialApp(
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
  var current = WordPair.random();

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

  var locked = false;
  var _teamNumberInProgress = 1234;
  var _serverUrlInProgress = "example.com";
  int? _teamNumber;
  String? _serverUrl;
  ExperimentBuilder? builder;

  String? _error;

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

  void connect() {
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
    builder = safeLoadBuilder(r'''[
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
      "fieldKey": "test"
    }
    ]''');
    notifyListeners();
  }

  void unlock() {
    locked = false;
    _teamNumberInProgress = _teamNumber ?? 1234;
    _serverUrlInProgress = _serverUrl ?? "example.com";
    builder = null;
    notifyListeners();
  }

  int getDisplayTeamNumber() {
    return _teamNumber ?? _teamNumberInProgress;
  }

  String getDisplayUrl() {
    return _serverUrl ?? _serverUrlInProgress;
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      case 2:
        page = ExperimentsPage(); //experiments
        break;
      case 3:
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
                  extended: constraints.maxWidth >= 600,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_fire_department),
                      label: Text('Experiments'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
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
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
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
                title: Text('${favorite.asLowerCase}'),
                leading: Icon(Icons.favorite),
                iconColor: theme.primaryColor,
              )
          ]
      );
    }
  }
}

class ExperimentsPage extends StatelessWidget {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "scouting");

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
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

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (appState.locked) {
                      appState.unlock();
                    } else if (_formKey.currentState!.validate()) {
                      appState.connect();
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
                SizedBox(width: 8),
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
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: "Team Number",
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
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: "Server",
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
            SizedBox(height: 10),
            ConfigCard(
              theme: theme,
              label: "Username",
              keyBoardType: TextInputType.name,
            ),
          ],
        ),
      ),
    );
  }
}

class ConfigCard extends StatelessWidget {
  const ConfigCard({
    super.key,
    required this.theme,
    required this.label,
    this.keyBoardType,
  });

  final ThemeData theme;
  final String label;
  final TextInputType? keyBoardType;

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
          ),
          keyboardType: keyBoardType,
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
