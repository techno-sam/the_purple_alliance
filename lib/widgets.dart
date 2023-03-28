import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';

class DisplayCard extends StatelessWidget {
  const DisplayCard({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Center(child: icon),
            if (icon != null) SizedBox(width: 8),
            Text(
              text,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

class TappableDisplayCard extends StatelessWidget {
  const TappableDisplayCard({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
  });

  final String text;
  final Function() onTap;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    var splashColorInvert = theme.colorScheme.primary;

    return Card(
      color: theme.colorScheme.primary,
      child: InkWell(
        onTap: () async {
          var ret = onTap();
          if (ret is Future) {
            await ret;
          }
        },
        splashColor: Color.fromARGB(255, 255 - splashColorInvert.red, 255 - splashColorInvert.green, 255 - splashColorInvert.blue),
        customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Center(child: icon),
              if (icon != null) SizedBox(width: 8),
              Text(
                text,
                style: style,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SyncInterval {
  t_1(description: "1 minute", interval: 1),
  t_5(description: "5 minutes", interval: 5),
  t_10(description: "10 minutes", interval: 10),
  t_20(description: "20 minutes", interval: 20),
  manual(description: "Manual")
  ;
  final String description;
  final int? interval;

  const SyncInterval({required this.description, this.interval});

  static SyncInterval fromName(String name) {
    return SyncInterval.values.firstWhere((element) => element.name == name, orElse: () => SyncInterval.manual);
  }
}

class SyncTimeSelector extends StatelessWidget {
  const SyncTimeSelector({
    super.key,
    required this.theme,
  });

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    var dropdownTextColor = theme.colorScheme.onPrimaryContainer;
    var appState = context.watch<MyAppState>();
    TextStyle style = TextStyle(
      color: dropdownTextColor,
    );
    return DropdownButtonFormField(
      items: [
        for (SyncInterval interval in SyncInterval.values)
          DropdownMenuItem(
              value: interval,
              child: Row(
                children: [
                  Icon(
                    interval.interval != null ? Icons.timer_outlined : Icons.timer_off_outlined,
                    color: dropdownTextColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                      interval.description,
                      style: style
                  ),
                ],
              )
          ),
      ],
      onChanged: (value) {
        if (value is SyncInterval) {
          appState.syncInterval = value;
        } else {
          appState.syncInterval = SyncInterval.manual;
        }
      },
      dropdownColor: theme.colorScheme.primaryContainer,
      value: appState.syncInterval,
    );
  }
}