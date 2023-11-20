import 'package:flutter/material.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/all_data_managers.dart';
import 'package:the_purple_alliance/state/search_system.dart';

class RankingsDialog extends StatelessWidget {
  const RankingsDialog({
    super.key,
    required this.theme,
    required this.rankedTeams,
    required this.dataManagers,
    required this.appState,
  });

  final ThemeData theme;
  final List<int> rankedTeams;
  final AllDataManagers dataManagers;
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: IntrinsicWidth(
        stepWidth: 56.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Ranked Teams",
                  style: theme.textTheme.headlineSmall,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < rankedTeams.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 8.0),
                            child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Text("${i + 1}."),
                                      const SizedBox(width: 10),
                                      Text(
                                        "${rankedTeams[i]}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(" - ${dataManagers.getTeamName(rankedTeams[i])}"),
                                      const Expanded(child: SizedBox()),
                                      Text(" ${dataManagers.getManager(rankedTeams[i]).getSearchRanking(appState.searchValues!).map((v, max) => '$v/$max')}")
                                    ],
                                  )
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}