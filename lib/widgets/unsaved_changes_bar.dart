import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';

class UnsavedChangesBar extends StatefulWidget {
  const UnsavedChangesBar({
    super.key,
    required this.theme,
    required this.initialValue,
  });

  final ThemeData theme;
  final bool Function() initialValue;

  @override
  State<UnsavedChangesBar> createState() => UnsavedChangesBarState();
}

class UnsavedChangesBarState extends State<UnsavedChangesBar> {

  UnsavedChangesBarState();

  bool unsavedChanges = false;


  @override
  void initState() {
    super.initState();
    unsavedChanges = widget.initialValue();
  }

  void setUnsavedChanges(bool unsavedChanges) {
    setState(() {
      this.unsavedChanges = unsavedChanges;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    appState.unsavedChangesBarState = WeakReference(this);
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
              IconButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(widget.theme.primaryColorLight),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await appState.saveConfig();
                },
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