import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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