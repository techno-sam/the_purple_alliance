import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/screens/main/main_page.dart';
import 'package:the_purple_alliance/utils/license_constants.dart' as license_constants;

Future<File> get _licenseAcceptedFile async {
  final path = await localPath;
  await Directory(path).create(recursive: true);
  return File('$path/license_accepted.txt');
}

enum LicenseStatus {
  accepted(true),
  outOfDate(false),
  notAccepted(false),
  ;
  final bool noActionNeeded;

  const LicenseStatus(this.noActionNeeded);
}

class MyLicensePage extends StatefulWidget {
  final Widget redirectTo;
  const MyLicensePage({super.key, required this.redirectTo});

  @override
  State<MyLicensePage> createState() => _MyLicensePageState();
}

class _MyLicensePageState extends State<MyLicensePage> {
  LicenseStatus licenseStatus = LicenseStatus.notAccepted;
  bool loading = true;

  bool _alreadyContinuing = false;

  @override
  void initState() {
    super.initState();

    _initAsync();
  }

  void _continueToApp() {
    if (!_alreadyContinuing) {
      _alreadyContinuing = true;
      Future.delayed(const Duration(), () {
        Navigator.of(context)
            .pushReplacement(
            MaterialPageRoute(builder: (_) => widget.redirectTo));
      });
    }
  }

  Future<void> _initAsync() async {
    setState(() {
      loading = true;
      licenseStatus = LicenseStatus.notAccepted;
    });

    LicenseStatus status = await _loadLicenseStatus();
    if (status.noActionNeeded) {
      _continueToApp();
    }
    setState(() {
      loading = false;
      licenseStatus = status;
    });
  }

  Future<LicenseStatus> _loadLicenseStatus() async {
    // read and parse license status
    final File licenseAcceptedFile = await _licenseAcceptedFile;
    if (await licenseAcceptedFile.exists()) {
      final String licenseData = await licenseAcceptedFile.readAsString();
      if (licenseData.trim() == license_constants.licenseHash.trim()) {
        return LicenseStatus.accepted;
      } else {
        return licenseData.trim().isEmpty ? LicenseStatus.notAccepted : LicenseStatus.outOfDate;
      }
    } else {
      return LicenseStatus.notAccepted;
    }
  }

  Future<void> _acceptLicense() async {
    File licenseAcceptedFile = await _licenseAcceptedFile;
    if (!await licenseAcceptedFile.exists()) {
      licenseAcceptedFile = await licenseAcceptedFile.create();
    }
    licenseAcceptedFile.writeAsString(license_constants.licenseHash, flush: true);
    setState(() {
      loading = false;
      licenseStatus = LicenseStatus.accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget inner = const Placeholder();
    final headerStyle = theme.textTheme.headlineSmall?.copyWith(color: Colors.black);

    if (loading) {
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Loading", style: headerStyle),
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            color: Colors.black,
          ),
        ],
      );
    } else if (!licenseStatus.noActionNeeded) { // need to present license
      final availableSpace = MediaQuery.of(context).size;
      inner = SizedBox(
        width: min(550, availableSpace.width * 0.9),
        height: availableSpace.height * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("The Purple Alliance License", style: headerStyle),
            Expanded(
              child: Card(
                child:
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      child: Center(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(license_constants.licenseText, style: theme.textTheme.bodyMedium),
                          ),
                        )
                      )
                    ),
                  )
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else if (Platform.isIOS) {
                      exit(0);
                    } else {
                      SystemNavigator.pop();
                      exit(0);
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.black),
                  label: Text("Cancel", style: theme.textTheme.labelSmall?.copyWith(color: Colors.black)),
                  style: (theme.textButtonTheme.style??const ButtonStyle())
                      .copyWith(backgroundColor: MaterialStatePropertyAll(Colors.red.shade400))
                ),
                ElevatedButton.icon(
                    onPressed: () {
                      _acceptLicense();
                    },
                    icon: const Icon(Icons.check_circle_outlined, color: Colors.black),
                    label: Text("Accept", style: theme.textTheme.labelSmall?.copyWith(color: Colors.black)),
                    style: (theme.textButtonTheme.style??const ButtonStyle())
                        .copyWith(backgroundColor: MaterialStatePropertyAll(Colors.greenAccent.shade400))
                ),
              ],
            )
          ],
        ),
      );
    } else { // should continue on...
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Continuing to app", style: headerStyle),
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            color: Colors.black,
          ),
        ],
      );
      _continueToApp();
    }

    return Container(
      decoration: const BoxDecoration(
          gradient: RadialGradient(
              colors: [
                Color(0xffd938db),
                Color(0xff3a00bc)
              ],
              center: Alignment.topLeft,
              radius: 1.75
          )
      ),
      child: Center(
        child: Card(
          color: Colors.white.withOpacity(0.35),
          shadowColor: Colors.black.withOpacity(0.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: inner
          ),
        ),
      ),
    );
  }
}