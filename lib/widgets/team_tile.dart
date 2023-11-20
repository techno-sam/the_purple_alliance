
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';

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