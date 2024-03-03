import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:adaptive_navigation/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/navigation/color_adaptive_scaffold.dart';
import 'package:the_purple_alliance/screens/main/scouting_page.dart';
import 'package:the_purple_alliance/screens/main/search_page.dart';
import 'package:the_purple_alliance/screens/main/settings_page.dart';
import 'package:the_purple_alliance/screens/main/team_selection.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';

enum Pages {
  teamSelection(Icons.list, "Teams"),
  editor(Icons.edit_note, "Editor"),
  search(Icons.manage_search_outlined, "Search"),
  settings(Icons.settings, "Settings"),
  ;
  final IconData icon;
  final String title;
  const Pages(this.icon, this.title);
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  var selectedIndex = 0;

  void _goToSettingsPage() {
    setState(() {
      selectedIndex = Pages.settings.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var config = context.watch<ConfigState>();
    config.goToSettingsPage = _goToSettingsPage;
    Widget page;
    Pages selectedPage = Pages.values[selectedIndex];
    switch (selectedPage) {
      case Pages.teamSelection:
        page = TeamSelectionPage(() {
          setState(() {
            selectedIndex = Pages.editor.index;
          });
        });
        break;
      case Pages.editor:
        page = ScoutingPage(() {
          setState(() {
            selectedIndex = Pages.teamSelection.index;
          });
        }); //experiments
        break;
      case Pages.search:
        page = SearchPage(() {
          setState(() {
            selectedIndex = Pages.editor.index;
          });
        });
        break;
      case Pages.settings:
        page = SettingsPage(); //settings
        break;
      default:
        throw UnimplementedError("No widget for $selectedIndex");
    }
    return GestureDetector(
      onTap: () {
        //log("Tapped somewhere!");
        FocusManager.instance.primaryFocus?.unfocus();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      },
      child: ColorAdaptiveNavigationScaffold(
        body: Container(
          color: oldColors ? Theme.of(context).colorScheme.primaryContainer : null,
          child: page,
        ),
        destinations: [
          for (Pages page in Pages.values)
            AdaptiveScaffoldDestination(title: page.title, icon: page.icon),
          if (config.teamColorReminder)
            const AdaptiveScaffoldDestination(title: 'Switch Color', icon: Icons.invert_colors),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) async {
          if (value == Pages.values.length) { // last item isn't actually a page, but a selector
            config.teamColorIsBlue = !config.teamColorIsBlue;
            await config.saveConfig();
          } else {
            setState(() {
              if (!config.locked || appState.builder == null) {
                value = Pages.settings.index;
              }
              if (selectedIndex != value && selectedIndex == Pages.settings.index && config.unsavedChanges) { //if we're leaving the settings page, save the config
                config.saveConfig().then((_) {
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
        navigationBackgroundColor: config.teamColorReminder ? (config.teamColorIsBlue ? Colors.blue.shade600 : Colors.red.shade600) : null,
        floatingActionButton: selectedPage == Pages.settings ? null : (getWindowType(context) >= AdaptiveWindowType.medium ? Row.new : Column.new)(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selectedPage != Pages.search)
              FloatingActionButton(
                heroTag: "runSync",
                onPressed: appState.runSynchronization,
                tooltip: "Synchronize data with server",
                child: const Icon(
                  Icons.sync_alt,
                ),
              ),
            if (selectedPage != Pages.search)
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
  }
}