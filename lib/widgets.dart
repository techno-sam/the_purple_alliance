import 'dart:math' as math;
import 'dart:io';

import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:adaptive_navigation/adaptive_navigation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:camera/camera.dart';

class CardPicture extends StatelessWidget {
  CardPicture({this.onTap, this.imagePath});

  final Function()? onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (imagePath != null) {
      return Card(
        child: Container(
          height: 300,
          padding: EdgeInsets.all(10.0),
          width: size.width * .70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
            image: DecorationImage(
                fit: BoxFit.cover, image: FileImage(File(imagePath as String))),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(3.0, 3.0),
                        blurRadius: 2.0,
                      )
                    ]
                ),
                child: IconButton(onPressed: (){
                  print('icon press');
                }, icon: Icon(Icons.delete, color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Card(
        elevation: 3,
        child: InkWell(
          onTap: this.onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 25),
            width: size.width * .70,
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach Picture',
                  style: TextStyle(fontSize: 17.0, color: Colors.grey[600]),
                ),
                Icon(
                  Icons.photo_camera,
                  color: Colors.indigo[400],
                )
              ],
            ),
          ),
        ));
  }
}

class TakePhoto extends StatefulWidget {
  final CameraDescription? camera;

  TakePhoto({super.key, this.camera});

  @override
  State<TakePhoto> createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera as CameraDescription,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  Future<XFile?> takePicture() async {
    if (_controller.value.isTakingPicture) {
      return null;
    }

    try {
      XFile file = await _controller.takePicture();
      return file;
    } on CameraException catch (e) {
      print(e);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take picture'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final file = await takePicture();
          Navigator.of(context).pop(file?.path);
        },
        child: Icon(Icons.camera_alt),
      ),

      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Container(
              child: CameraPreview(_controller),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        }
      )
    );
  }
}

class CommentList extends StatelessWidget {
  const CommentList({
    super.key,
    required this.theme,
    required this.comments,
  });

  final ThemeData theme;
  final Map<String, String> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.primaryColorDark,
      child: Column(
        children: [
          const Divider(color: Colors.black, indent: 20, endIndent: 20,),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  for (MapEntry<String, String> comment in comments.entries)
                    SizedBox(
                      height: 200,
//                      aspectRatio: _isLargeScreen(context) ? 4 : _isMediumScreen(context) ? 3 : 2,
                      child: Card(
                        color: theme.primaryColorLight,
                        elevation: 2,
                        child: Container(
                          margin: const EdgeInsets.all(4.0),
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment.key, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
                              Divider(color: theme.colorScheme.onSurface, endIndent: 50),
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      comment.value,
                                      style: TextStyle(color: theme.colorScheme.onSurface)
                                    )
                                  )
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StarRating extends StatefulWidget {
  const StarRating({
    super.key,
    required this.initialRating,
    required this.averageRating,
    this.onChanged,
    this.starCount = 5,
    this.starSize = 20.0,
    this.interactable = true,
    this.color,
  });

  final double initialRating;
  final double? averageRating;
  final Function(double)? onChanged;
  final int starCount;
  final double starSize;
  final bool interactable;
  final Color? color;

  @override
  State<StarRating> createState() => _StarRatingState(initialRating);
}

double roundDouble(double value, int places){
  num mod = math.pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}

class _StarRatingState extends State<StarRating> {
  double _rating;

  _StarRatingState(this._rating);

  Widget buildStar(BuildContext context, int index) {
    Icon icon;
    if (index >= _rating) {
      icon = const Icon(Icons.star_border);
    } else if (index > _rating - 1 && index < _rating) {
      icon = Icon(
        Icons.star_half,
        color: widget.color,
      );
    } else {
      icon = Icon(
        Icons.star,
        color: widget.color,
      );
    }
    return InkResponse(
      onTap: widget.interactable ? () {
        if (widget.onChanged != null) {
          widget.onChanged!(index + 1.0);
        }
        setState(() {
          _rating = index + 1.0;
        });
      } : null,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.starCount; i++)
          buildStar(context, i),
        if (widget.averageRating != null)
          const SizedBox(width: 4),
        if (widget.averageRating != null)
          Text("Avg: ${roundDouble(widget.averageRating ?? 0, 2)}/${widget.starCount+0.0}"),
      ],
    );
  }
}

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
    var appState = context.watch<MyAppState>();
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
          appState.imageSyncMode = value;
        } else {
          appState.imageSyncMode = ImageSyncMode.manual;
        }
      },
      dropdownColor: theme.colorScheme.primaryContainer,
      value: appState.imageSyncMode,
    );
  }
}

class ColorAdaptiveNavigationScaffold extends StatelessWidget {
  const ColorAdaptiveNavigationScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.endDrawer,
    this.bottomSheet,
    this.backgroundColor,
    this.navigationBackgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.drawerDragStartBehavior = DragStartBehavior.start,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
    this.navigationTypeResolver,
    this.drawerHeader,
    this.drawerFooter,
    this.fabInRail = true,
    this.includeBaseDestinationsInMenu = true,
    this.bottomNavigationOverflow = 5,
  }) : super(key: key);

  /// See [Scaffold.appBar].
  final PreferredSizeWidget? appBar;

  /// See [Scaffold.body].
  final Widget body;

  /// See [Scaffold.floatingActionButton].
  final Widget? floatingActionButton;

  /// See [Scaffold.floatingActionButtonLocation].
  ///
  /// Ignored if [fabInRail] is true.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// See [Scaffold.floatingActionButtonAnimator].
  ///
  /// Ignored if [fabInRail] is true.
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;

  /// See [Scaffold.persistentFooterButtons].
  final List<Widget>? persistentFooterButtons;

  /// See [Scaffold.endDrawer].
  final Widget? endDrawer;

  /// See [Scaffold.drawerScrimColor].
  final Color? drawerScrimColor;

  /// See [Scaffold.backgroundColor].
  final Color? backgroundColor;

  /// See [NavigationRail.backgroundColor].
  final Color? navigationBackgroundColor;

  /// See [Scaffold.bottomSheet].
  final Widget? bottomSheet;

  /// See [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  /// See [Scaffold.primary].
  final bool primary;

  /// See [Scaffold.drawerDragStartBehavior].
  final DragStartBehavior drawerDragStartBehavior;

  /// See [Scaffold.extendBody].
  final bool extendBody;

  /// See [Scaffold.extendBodyBehindAppBar].
  final bool extendBodyBehindAppBar;

  /// See [Scaffold.drawerEdgeDragWidth].
  final double? drawerEdgeDragWidth;

  /// See [Scaffold.drawerEnableOpenDragGesture].
  final bool drawerEnableOpenDragGesture;

  /// See [Scaffold.endDrawerEnableOpenDragGesture].
  final bool endDrawerEnableOpenDragGesture;

  /// The index into [destinations] for the current selected
  /// [AdaptiveScaffoldDestination].
  final int selectedIndex;

  /// Defines the appearance of the items that are arrayed within the
  /// navigation.
  ///
  /// The value must be a list of two or more [AdaptiveScaffoldDestination]
  /// values.
  final List<AdaptiveScaffoldDestination> destinations;

  /// Called when one of the [destinations] is selected.
  ///
  /// The stateful widget that creates the adaptive scaffold needs to keep
  /// track of the index of the selected [AdaptiveScaffoldDestination] and call
  /// `setState` to rebuild the adaptive scaffold with the new [selectedIndex].
  final ValueChanged<int>? onDestinationSelected;

  /// Determines the navigation type that the scaffold uses.
  final NavigationTypeResolver? navigationTypeResolver;

  /// The leading item in the drawer when the navigation has a drawer.
  ///
  /// If null, then there is no header.
  final Widget? drawerHeader;

  /// The footer item in the drawer when the navigation has a drawer.
  ///
  /// If null, then there is no footer.
  final Widget? drawerFooter;

  /// Whether the [floatingActionButton] is inside or the rail or in the regular
  /// spot.
  ///
  /// If true, then [floatingActionButtonLocation] and
  /// [floatingActionButtonAnimation] are ignored.
  final bool fabInRail;

  /// Weather the overflow menu defaults to include overflow destinations and
  /// the overflow destinations.
  final bool includeBaseDestinationsInMenu;

  /// Maximum number of items to display in [bottomNavigationBar]
  final int bottomNavigationOverflow;

  NavigationType _defaultNavigationTypeResolver(BuildContext context) {
    if (_isLargeScreen(context)) {
      return NavigationType.permanentDrawer;
    } else if (_isMediumScreen(context)) {
      return NavigationType.rail;
    } else {
      return NavigationType.bottom;
    }
  }

  Drawer _defaultDrawer(List<AdaptiveScaffoldDestination> destinations) {
    return Drawer(
      backgroundColor: navigationBackgroundColor,
      child: ListView(
        children: [
          if (drawerHeader != null) drawerHeader!,
          for (int i = 0; i < destinations.length; i++)
            ListTile(
              leading: Icon(destinations[i].icon),
              title: Text(destinations[i].title),
              onTap: () {
                onDestinationSelected?.call(i);
              },
            ),
          const Spacer(),
          if (drawerFooter != null) drawerFooter!,
        ],
      ),
    );
  }

  Widget _buildBottomNavigationScaffold() {
    final bottomDestinations = destinations.sublist(
      0,
      math.min(destinations.length, bottomNavigationOverflow),
    );
    final drawerDestinations = destinations.length > bottomNavigationOverflow
        ? destinations.sublist(
        includeBaseDestinationsInMenu ? 0 : bottomNavigationOverflow)
        : <AdaptiveScaffoldDestination>[];
    return Scaffold(
      key: key,
      body: body,
      appBar: appBar,
      drawer: drawerDestinations.isEmpty
          ? null
          : _defaultDrawer(drawerDestinations),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: navigationBackgroundColor,
        items: [
          for (final destination in bottomDestinations)
            BottomNavigationBarItem(
              icon: Icon(destination.icon),
              label: destination.title,
            ),
        ],
        selectedItemColor: navigationBackgroundColor == null ? null : Colors.grey.shade200,
        currentIndex: selectedIndex,
        onTap: onDestinationSelected ?? (_) {},
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavigationRailScaffold() {
    const int railDestinationsOverflow = 7;
    final railDestinations = destinations.sublist(
      0,
      math.min(destinations.length, railDestinationsOverflow),
    );
    final drawerDestinations = destinations.length > railDestinationsOverflow
        ? destinations.sublist(
        includeBaseDestinationsInMenu ? 0 : railDestinationsOverflow)
        : <AdaptiveScaffoldDestination>[];
    return Scaffold(
      key: key,
      appBar: appBar,
      drawer: drawerDestinations.isEmpty
          ? null
          : _defaultDrawer(drawerDestinations),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: navigationBackgroundColor,
            leading: fabInRail ? floatingActionButton : null,
            destinations: [
              for (final destination in railDestinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon, color: navigationBackgroundColor == null ? null : Colors.black),
                  label: Text(destination.title),
                ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected ?? (_) {},
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
          ),
          Expanded(
            child: body,
          ),
        ],
      ),
      floatingActionButton: fabInRail ? null : floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: true,
      drawerDragStartBehavior: drawerDragStartBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
    );
  }

  Widget _buildNavigationDrawerScaffold() {
    return Scaffold(
      key: key,
      body: body,
      appBar: appBar,
      drawer: Drawer(
        child: Column(
          children: [
            if (drawerHeader != null) drawerHeader!,
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.title),
                selected: destinations.indexOf(destination) == selectedIndex,
                onTap: () => _destinationTapped(destination),
              ),
            const Spacer(),
            if (drawerFooter != null) drawerFooter!,
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: true,
      drawerDragStartBehavior: drawerDragStartBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
    );
  }

  Widget _buildPermanentDrawerScaffold() {
    return Row(
      children: [
        Drawer(
          backgroundColor: navigationBackgroundColor,
          child: Column(
            children: [
              if (drawerHeader != null) drawerHeader!,
              for (final destination in destinations)
                ListTile(
                  leading: Icon(destination.icon),
                  title: Text(destination.title),
                  selected: destinations.indexOf(destination) == selectedIndex,
                  onTap: () => _destinationTapped(destination),
                  selectedColor: navigationBackgroundColor == null ? null : Colors.grey.shade200,
                  iconColor: navigationBackgroundColor == null ? null : Colors.black,
                ),
              const Spacer(),
              if (drawerFooter != null) drawerFooter!,
            ],
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
        ),
        Expanded(
          child: Scaffold(
            key: key,
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            floatingActionButtonAnimator: floatingActionButtonAnimator,
            persistentFooterButtons: persistentFooterButtons,
            endDrawer: endDrawer,
            bottomSheet: bottomSheet,
            backgroundColor: backgroundColor,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            primary: true,
            drawerDragStartBehavior: drawerDragStartBehavior,
            extendBody: extendBody,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            drawerScrimColor: drawerScrimColor,
            drawerEdgeDragWidth: drawerEdgeDragWidth,
            drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
            endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final NavigationTypeResolver navigationTypeResolver =
        this.navigationTypeResolver ?? _defaultNavigationTypeResolver;
    final navigationType = navigationTypeResolver(context);
    switch (navigationType) {
      case NavigationType.bottom:
        return _buildBottomNavigationScaffold();
      case NavigationType.rail:
        return _buildNavigationRailScaffold();
      case NavigationType.drawer:
        return _buildNavigationDrawerScaffold();
      case NavigationType.permanentDrawer:
        return _buildPermanentDrawerScaffold();
    }
  }

  void _destinationTapped(AdaptiveScaffoldDestination destination) {
    final index = destinations.indexOf(destination);
    if (index != selectedIndex) {
      onDestinationSelected?.call(index);
    }
  }
}

bool _isLargeScreen(BuildContext context) =>
    getWindowType(context) >= AdaptiveWindowType.large;
bool _isMediumScreen(BuildContext context) =>
    getWindowType(context) == AdaptiveWindowType.medium;