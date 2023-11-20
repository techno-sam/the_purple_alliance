import 'package:flutter/material.dart';
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
      color: !oldColors ? null : theme.colorScheme.onPrimary,
    );

    return Card(
      color: !oldColors ? null : theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Center(child: icon),
            if (icon != null) const SizedBox(width: 8),
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
      color: oldColors ? theme.colorScheme.onPrimary : null,
    );

    var splashColorInvert = theme.colorScheme.primary;

    return Card(
      color: oldColors ? theme.colorScheme.primary : null,
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
              if (icon != null) const SizedBox(width: 8),
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