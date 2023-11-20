
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/widgets/scouting/scouting_layout.dart';

class ScoutingPage extends StatelessWidget {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "scouting");
  static final GlobalKey _scrollKey = GlobalKey(debugLabel: "scroll");

  ScoutingPage(this.goToTeamSelectionPage, {super.key});

  final void Function() goToTeamSelectionPage;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var children = buildScoutingLayout(context, appState.builder, goToTeamSelectionPage);
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