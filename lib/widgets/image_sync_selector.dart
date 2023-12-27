import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';

enum ImageSyncMode {
  all(description: "All Images", icon: Icons.cloud_sync),
  selected(description: "Selected Team", icon: Icons.sync_problem),
  manual(description: "Manual", icon: Icons.sync_disabled)
  ;
  final String description;
  final IconData icon;

  const ImageSyncMode({required this.description, required this.icon});

  static ImageSyncMode fromName(String name) {
    return ImageSyncMode.values.firstWhere((element) => element.name == name, orElse: () => ImageSyncMode.manual);
  }
}

class ImageSyncSelector extends StatelessWidget {
  const ImageSyncSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var dropdownTextColor = theme.colorScheme.onPrimaryContainer;
    var config = context.watch<ConfigState>();
    TextStyle style = TextStyle(
      color: dropdownTextColor,
    );
    return DropdownButtonFormField(
      items: [
        for (ImageSyncMode mode in ImageSyncMode.values)
          DropdownMenuItem(
              value: mode,
              child: Row(
                children: [
                  Icon(
                      mode.icon,
                      color: dropdownTextColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                      mode.description,
                      style: style
                  ),
                ],
              )
          ),
      ],
      onChanged: (value) {
        if (value is ImageSyncMode) {
          config.imageSyncMode = value;
        } else {
          config.imageSyncMode = ImageSyncMode.manual;
        }
      },
      dropdownColor: theme.colorScheme.primaryContainer,
      value: config.imageSyncMode,
    );
  }
}