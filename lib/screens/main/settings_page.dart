
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';
import 'package:the_purple_alliance/utils/util.dart';
import 'package:the_purple_alliance/widgets/image_sync_selector.dart';
import 'package:the_purple_alliance/widgets/simple_password_form_field.dart';
import 'package:the_purple_alliance/widgets/sync_time_selector.dart';
import 'package:the_purple_alliance/widgets/unsaved_changes_bar.dart';

class SettingsPage extends StatelessWidget {

  static final GlobalKey<FormState> _formKey = GlobalKey<FormState>(debugLabel: "settings");
  static final GlobalKey<FormFieldState<String>> _teamNumberKey = GlobalKey<FormFieldState<String>>(debugLabel: "teamNumber");
  static final GlobalKey<FormFieldState<String>> _serverKey = GlobalKey<FormFieldState<String>>(debugLabel: "serverUrl");
  static final GlobalKey<FormFieldState<String>> _passwordKey = GlobalKey<FormFieldState<String>>(debugLabel: "password");
  static final GlobalKey<FormFieldState<String>> _usernameKey = GlobalKey<FormFieldState<String>>(debugLabel: "username");

  final MobileScannerController _cameraController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var config = context.watch<ConfigState>();
    final theme = Theme.of(context);
    var genericTextStyle = TextStyle(color: theme.colorScheme.onPrimaryContainer);
    var buttonColor = (config.locked && appState.builder == null) ? const Color.fromARGB(0, 0, 0, 0) : null;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          children: [
            UnsavedChangesBar(theme: theme, initialValue: () => config.unsavedChanges),
            // authentication config
            AuthenticationConfig(formKey: _formKey, buttonColor: buttonColor, cameraController: _cameraController, theme: theme, teamNumberKey: _teamNumberKey, genericTextStyle: genericTextStyle, serverKey: _serverKey, usernameKey: _usernameKey, passwordKey: _passwordKey),
            const SizedBox(height: 10),
            // sync interval config
            Card(
              color: !oldColors ? null : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sync interval",
                      style: genericTextStyle,
                    ),
                    const SyncTimeSelector(),
                    const SizedBox(height: 12),
                    Text(
                      "Image sync",
                      style: genericTextStyle,
                    ),
                    const ImageSyncSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // color configs
            Card(
              color: !oldColors ? null : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            "Colorful Team Buttons",
                            style: genericTextStyle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
//                        const SizedBox(width: 2),
                        Switch(
                          value: config.colorfulTeams,
                          onChanged: (value) {
                            config.colorfulTeams = value;
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            "Team Color Reminder",
                            style: genericTextStyle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Switch(
                          value: config.teamColorReminder,
                          onChanged: (value) {
                            config.teamColorReminder = value;
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // data reset buttons
            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Clear all local data?"),
                          content: const Text("This will clear all local data, and force a sync with the server."),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await appState.clearAllData();
                              },
                              child: const Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.black,
                        ),
                        SizedBox(width: 10),
                        Text(
                            "Force sync data\n(Will clear all local data)",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                            )
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Clear all local images?"),
                          content: const Text("This will clear all local images."),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                appState.imageSyncManager.downloadedUUIDs.clear();
                                appState.imageSyncManager.knownImages.clear();
                              },
                              child: const Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.black,
                        ),
                        SizedBox(width: 10),
                        Text(
                            "Clear images\n(Keeps files)",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                            )
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class AuthenticationConfig extends StatelessWidget {
  const AuthenticationConfig({
    super.key,
    required GlobalKey<FormState> formKey,
    required this.buttonColor,
    required MobileScannerController cameraController,
    required this.theme,
    required GlobalKey<FormFieldState<String>> teamNumberKey,
    required this.genericTextStyle,
    required GlobalKey<FormFieldState<String>> serverKey,
    required GlobalKey<FormFieldState<String>> usernameKey,
    required GlobalKey<FormFieldState<String>> passwordKey,
  }) : _formKey = formKey, _cameraController = cameraController, _teamNumberKey = teamNumberKey, _serverKey = serverKey, _usernameKey = usernameKey, _passwordKey = passwordKey;

  final GlobalKey<FormState> _formKey;
  final Color? buttonColor;
  final MobileScannerController _cameraController;
  final ThemeData theme;
  final GlobalKey<FormFieldState<String>> _teamNumberKey;
  final TextStyle genericTextStyle;
  final GlobalKey<FormFieldState<String>> _serverKey;
  final GlobalKey<FormFieldState<String>> _usernameKey;
  final GlobalKey<FormFieldState<String>> _passwordKey;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var config = context.watch<ConfigState>();
    return Row(
      children: [
        Column(
          children: [
            if (config.locked)
              IconButton(
                onPressed: () async {
                  await appState.reconnect();
                },
                icon: const Icon(Icons.refresh),
                tooltip: "Refresh scheme",
              ),
            IconButton(
              onPressed: () async {
                if (config.locked) {
                  if (appState.builder != null) { //don't unlock if currently connecting - that could cause problems
                    await appState.unlock();
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Connecting"),
                          content: const Text("Disconnecting while connecting can cause issues. Are you sure you want to disconnect?"),
                          actions: [
                            TextButton(
                              child: const Text("Cancel"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: const Text("Disconnect"),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await appState.unlock();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                } else if (_formKey.currentState!.validate()) {
                  await appState.connect();
                }
              },
              highlightColor: buttonColor,
              hoverColor: buttonColor,
              focusColor: buttonColor,
              icon: Icon(
                config.locked ? Icons.lock_outlined : Icons.wifi,
                color: config.locked ? (appState.builder == null ? Colors.amber : Colors.red) : Colors.green,
              ),
              tooltip: config.locked
                  ? (appState.builder == null ? "Connecting" : "Unlock connection settings")
                  : "Connect",
            ),
            if (config.locked || _isQRScanningSupported())
              IconButton(
                onPressed: () {
                  const identifier = "com.team1661.the_purple_alliance";
                  if (config.locked) { //provide connection data
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: ((context) {
                            return Scaffold(
                              appBar: AppBar(
                                title: const Text("Connection Data"),
                                centerTitle: true,
                              ),
                              body: Center(
                                child: QrImageView(
                                  data: jsonEncode({
                                    "identifier": identifier,
                                    "team_number": config.getDisplayTeamNumber(),
                                    "server": config.serverUrl,
                                    "password": config.password,
                                  }),
                                  size: 280,
                                ),
                              ),
                            );
                          }),
                        )
                    );
                  } else if (_isQRScanningSupported()) { //read connection data
                    try {
                      var alreadyGot = false; //prevent multiple handling of a qr code, which crashes Navigator
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: ((context) {
                            return Scaffold(
                              appBar: AppBar(
                                title: const Text("Scan"),
                                actions: [
                                  IconButton(
                                    color: Colors.white,
                                    icon: ValueListenableBuilder(
                                      valueListenable: _cameraController.torchState,
                                      builder: (context, state, child) {
                                        switch (state) {
                                          case TorchState.off:
                                            return const Icon(Icons.flash_off, color: Colors.grey);
                                          case TorchState.on:
                                            return const Icon(Icons.flash_on, color: Colors.yellow);
                                        }
                                      },
                                    ),
                                    iconSize: 32.0,
                                    onPressed: () => _cameraController.toggleTorch(),
                                  ),
                                  IconButton(
                                    color: Colors.white,
                                    icon: ValueListenableBuilder(
                                      valueListenable: _cameraController.cameraFacingState,
                                      builder: (context, state, child) {
                                        switch (state) {
                                          case CameraFacing.front:
                                            return const Icon(Icons.camera_front, color: Colors.blue);
                                          case CameraFacing.back:
                                            return const Icon(Icons.camera_rear, color: Colors.blue);
                                        }
                                      },
                                    ),
                                    iconSize: 32.0,
                                    onPressed: () => _cameraController.switchCamera(),
                                  ),
                                ],
                              ),
                              body: MobileScanner(
                                controller: _cameraController,
                                onDetect: (capture) async {
                                  final List<Barcode> barcodes = capture.barcodes;
                                  log("barcodes: $barcodes");
                                  for (final barcode in barcodes) {
                                    if (alreadyGot) break;
                                    if (barcode.format == BarcodeFormat.qrCode) {
                                      var value = barcode.rawValue;
                                      log("Found barcode: $value");
                                      if (value != null) {
                                        try {
                                          var decoded = jsonDecode(value);
                                          if (decoded is Map<String, dynamic> && decoded.containsKey("identifier") &&
                                              decoded["identifier"] == identifier && decoded["team_number"] is int &&
                                              decoded["server"] is String && decoded["password"] is String) {
                                            config.teamNumberInProgress = decoded["team_number"];
                                            config.serverUrlInProgress = decoded["server"];
                                            config.password = decoded["password"];
                                            log("Decoded number: ${config.teamNumberInProgress}");
                                            appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text("Obtained connection data")));
                                            log("Connection data got!");
                                            alreadyGot = true;
                                            appState.notifySettingsUpdate();
                                            Navigator.pop(context);
                                            break;
                                          }
                                        } catch (e) {
                                          // pass
                                        }
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      );
                    } on MissingPluginException {
                      appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(
                        content: Text("QR Scanning is not supported on your platform"),
                      ));
                    }
                  } else {
                    appState.scaffoldKey.currentState?.showSnackBar(const SnackBar(
                      content: Text("QR Scanning is not supported on your platform"),
                    ));
                  }
                },
                icon: Icon(
                  config.locked ? Icons.qr_code : Icons.qr_code_scanner,
                ),
                tooltip: config.locked ? "Show QR code" : "Scan QR code",
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
              color: config.locked ? theme.colorScheme
                  .tertiaryContainer : (!oldColors ? null : theme.colorScheme.primaryContainer),
              child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                      children: [
                        TextFormField(
                          key: _teamNumberKey,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            labelText: "Team Number",
                            labelStyle: genericTextStyle,
                          ),
                          controller: TextEditingController(text: "${config.getDisplayTeamNumber()}"),
                          keyboardType: TextInputType.number,
                          readOnly: config.locked,
    //                                  initialValue: "${appState.getDisplayTeamNumber()}",
                          onChanged: (value) {
                            var number = int.tryParse(value);
                            if (number != null) {
                              config.teamNumberInProgress = number;
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
                          key: _serverKey,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            labelText: "Server",
                            labelStyle: genericTextStyle,
                          ),
                          controller: TextEditingController(text: config.getDisplayUrl()),
                          keyboardType: TextInputType.url,
                          readOnly: config.locked,
                          onChanged: (value) {
                            config.serverUrlInProgress = value;
                          },
                          validator: (String? value) {
                            if (value == null || value == "") {
                              return "Must have a url!";
                            }
                            return verifyServerUrl(value);
                          },
                        ),
                        TextFormField(
                          key: _usernameKey,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            labelText: "Name",
                            labelStyle: genericTextStyle,
                          ),
                          controller: TextEditingController(text: config.username),
                          keyboardType: TextInputType.name,
                          readOnly: config.locked,
                          onChanged: (value) {
                            config.username = value;
                          },
                          validator: (String? value) {
                            if (value == null || value == "") {
                              return "Must have a name set";
                            }
                            return null;
                          },
                        ),
                        SimplePasswordFormField(formKey: _passwordKey, genericTextStyle: genericTextStyle, config: config),
                      ]
                  )
              )
          ),
        ),
      ],
    );
  }
}

bool _isQRScanningSupported() {
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}