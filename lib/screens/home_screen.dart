import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../provider/theme_provider.dart';
import '../models/stamp_config.dart';
import '../services/location_service.dart';
import '../widgets/stamp_overlay.dart';
import '../widgets/watch_ad_dialog.dart';
import 'edit_screen.dart';
import 'map_screen.dart';
import 'privacy_policy_screen.dart';
import 'preview_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _cameraError;
  File? _lastCapturedFile;
  bool _capturing = false;
  bool _showLiveLocation = false;
  LocationResult? _liveLocation;
  StampConfig _stampConfig = StampConfig(showLocation: true);
  late final ValueNotifier<StampConfig> _stampNotifier = ValueNotifier(
    _stampConfig,
  );
  Timer? _clockTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _locationSubscription;
  double _overlayRotation = 0;
  Offset _overlayFraction = const Offset(0.04, 0.72);
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoomLevel = 1;
  double _zoomStart = 1;
  bool _modificationsUnlocked = false;
  bool _dateTimeModified = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_dateTimeModified) {
        _setStampConfig(_stampConfig.copyWith(dateTime: DateTime.now()));
      }
    });
    _initCamera();
    _loadLocationOnLaunch();
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final nextRotation =
          event.x.abs() > event.y.abs()
              ? (event.x > 0 ? math.pi / 2 : -math.pi / 2)
              : (event.y > 0 ? 0.0 : math.pi);
      if (mounted && nextRotation != _overlayRotation) {
        setState(() => _overlayRotation = nextRotation);
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
      );
      _initFuture = _controller!.initialize();
      await _initFuture;
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _zoomLevel = _minZoom.clamp(0.5, _maxZoom);
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    _stampNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadLocationOnLaunch() async {
    final cached = await LocationService.getCachedLocation();
    if (mounted && cached != null) _setLocation(cached);
    final fresh = await LocationService.getCurrentLocation();
    if (mounted && fresh != null) {
      _setLocation(fresh);
      _locationSubscription?.cancel();
      _locationSubscription = LocationService.positionStream.listen((
        position,
      ) async {
        final result = await LocationService.fromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (mounted) _setLocation(result);
      });
    }
  }

  void _setLocation(LocationResult result) {
    setState(() {
      _liveLocation = result;
      _showLiveLocation = true;
      _setStampConfig(
        _stampConfig.copyWith(
          showLocation: true,
          latitude: result.latitude,
          longitude: result.longitude,
          address: result.address,
        ),
      );
    });
  }

  void _setStampConfig(StampConfig config) {
    _stampConfig = config;
    _stampNotifier.value = config;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final xfile = await controller.takePicture();
      if (!mounted) return;
      setState(() => _lastCapturedFile = File(xfile.path));
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PreviewEditorScreen(
                  imagePath: xfile.path,
                  initialConfig: _stampConfig,
                  initialPosition: _overlayFraction,
                  onSaveStarted: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo saved to gallery')),
                    );
                  },
                ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _openEditor(File file, {bool autoSave = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditScreen(
              imageFile: file,
              initialConfig: _stampConfig,
              autoSave: autoSave,
            ),
      ),
    );
  }

  Future<void> _uploadPhoto() async {
    Navigator.pop(context); // close drawer
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    if (!mounted) return;
    _openEditor(File(xfile.path));
  }

  Future<void> _modifyLatest() async {
    Navigator.pop(context); // close drawer
    if (_lastCapturedFile != null) {
      _openEditor(_lastCapturedFile!);
      return;
    }
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    if (!mounted) return;
    _openEditor(File(xfile.path));
  }

  Future<void> _toggleLiveLocation() async {
    if (_showLiveLocation) {
      setState(() {
        _showLiveLocation = false;
        _liveLocation = null;
      });
      return;
    }

    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable or permission denied.'),
        ),
      );
      return;
    }
    _setLocation(result);
  }

  Future<void> _openPreviewSettings() async {
    final projectController = TextEditingController(
      text: _stampConfig.projectName,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (modalContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(modalContext).bottom + 20,
            ),
            child: StatefulBuilder(
              builder:
                  (context, setModalState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview Setting',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: projectController,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Free visual customization',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _stampConfig.fontFamily,
                        decoration: const InputDecoration(
                          labelText: 'Font family',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'monospace',
                            child: Text('Monospace'),
                          ),
                          DropdownMenuItem(
                            value: 'sans-serif',
                            child: Text('Sans serif'),
                          ),
                          DropdownMenuItem(
                            value: 'serif',
                            child: Text('Serif'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(
                            () => _setStampConfig(
                              _stampConfig.copyWith(fontFamily: value),
                            ),
                          );
                          setModalState(() {});
                        },
                      ),
                      Row(
                        children: [
                          const Text('Text size'),
                          Expanded(
                            child: Slider(
                              min: 10,
                              max: 22,
                              divisions: 12,
                              value: _stampConfig.textSize,
                              label: '${_stampConfig.textSize.round()}px',
                              onChanged: (value) {
                                setState(
                                  () => _setStampConfig(
                                    _stampConfig.copyWith(textSize: value),
                                  ),
                                );
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Box size'),
                          Expanded(
                            child: Slider(
                              min: 0.55,
                              max: 1.8,
                              divisions: 25,
                              value: _stampConfig.boxScale,
                              label:
                                  '${(_stampConfig.boxScale * 100).round()}%',
                              onChanged: (value) {
                                setState(
                                  () => _setStampConfig(
                                    _stampConfig.copyWith(boxScale: value),
                                  ),
                                );
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      SegmentedButton<StampLayout>(
                        segments: const [
                          ButtonSegment(
                            value: StampLayout.portrait,
                            label: Text('Portrait Style'),
                          ),
                          ButtonSegment(
                            value: StampLayout.landscape,
                            label: Text('Landscape Style'),
                          ),
                        ],
                        selected: {_stampConfig.layout},
                        onSelectionChanged: (value) {
                          setState(
                            () => _setStampConfig(
                              _stampConfig.copyWith(layout: value.first),
                            ),
                          );
                          setModalState(() {});
                        },
                      ),
                      Row(
                        children: [
                          const Text('Text color'),
                          const SizedBox(width: 12),
                          ..._colorChoices((color) {
                            setState(
                              () => _setStampConfig(
                                _stampConfig.copyWith(textColor: color),
                              ),
                            );
                            setModalState(() {});
                          }, _stampConfig.textColor),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Box color'),
                          const SizedBox(width: 12),
                          ..._colorChoices((color) {
                            setState(
                              () => _setStampConfig(
                                _stampConfig.copyWith(backgroundColor: color),
                              ),
                            );
                            setModalState(() {});
                          }, _stampConfig.backgroundColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Change Location via Map'),
                          onPressed: () async {
                            final result = await Navigator.push<LocationResult>(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => MapScreen(
                                      initialLocation: _liveLocation,
                                    ),
                              ),
                            );
                            if (mounted && result != null) _setLocation(result);
                            if (context.mounted) setModalState(() {});
                          },
                        ),
                      ),
                      _previewAction(
                        'Modify Date',
                        Icons.calendar_month,
                        () async {
                          await _unlock(() => _pickDate(modalContext));
                          setModalState(() {});
                        },
                      ),
                      _previewAction('Modify Time', Icons.schedule, () async {
                        await _unlock(() => _pickTime(modalContext));
                        setModalState(() {});
                      }),
                      _previewAction(
                        'Modify Location',
                        Icons.location_on_outlined,
                        () async {
                          await _unlock(() async {
                            final result =
                                await LocationService.getCurrentLocation();
                            if (mounted && result != null) _setLocation(result);
                          });
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(
                              () => _setStampConfig(
                                _stampConfig.copyWith(
                                  projectName: projectController.text,
                                ),
                              ),
                            );
                            Navigator.pop(modalContext);
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
    );
    projectController.dispose();
  }

  Widget _previewAction(String label, IconData icon, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.lock_outline, size: 18),
        onTap: onTap,
      );

  List<Widget> _colorChoices(ValueChanged<Color> onSelected, Color selected) {
    const colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.yellow,
      Colors.cyan,
    ];
    return colors
        .map(
          (color) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelected(color),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child:
                    selected.toARGB32() == color.toARGB32()
                        ? const Icon(Icons.check, size: 16, color: Colors.grey)
                        : null,
              ),
            ),
          ),
        )
        .toList();
  }

  Future<void> _unlock(Future<void> Function() action) async {
    if (_modificationsUnlocked) {
      await action();
      return;
    }
    var rewarded = false;
    await showWatchAdToUnlockDialog(
      context,
      onUnlocked: () async {
        rewarded = true;
        await action();
      },
    );
    if (mounted && rewarded) setState(() => _modificationsUnlocked = true);
  }

  Future<void> _pickDate(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      initialDate: _stampConfig.dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() {
        _dateTimeModified = true;
        _setStampConfig(
          _stampConfig.copyWith(
            dateTime: DateTime(
              value.year,
              value.month,
              value.day,
              _stampConfig.dateTime.hour,
              _stampConfig.dateTime.minute,
            ),
          ),
        );
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_stampConfig.dateTime),
    );
    if (value != null && mounted) {
      setState(() {
        _dateTimeModified = true;
        _setStampConfig(
          _stampConfig.copyWith(
            dateTime: DateTime(
              _stampConfig.dateTime.year,
              _stampConfig.dateTime.month,
              _stampConfig.dateTime.day,
              value.hour,
              value.minute,
            ),
          ),
        );
      });
    }
  }

  Future<void> _shareApp() async {
    try {
      final apkPath = await MethodChannel(
        'com.kronocam.app/share_apk',
      ).invokeMethod<String>('getApkPath');
      if (apkPath != null && apkPath.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(apkPath)],
            text: 'KronoCam - Timestamp Camera',
          ),
        );
        return;
      }
    } catch (_) {
      // Fall through to a text share when the installed APK path is unavailable.
    }
    await SharePlus.instance.share(
      ShareParams(
        text:
            'KronoCam - Timestamp Camera\n\n'
            'Capture photos with live date, time, GPS coordinates, address '
            'and project stamps. Edit date, time, location and project name, '
            'then save the stamped photo to your gallery.\n\n'
            'Made by Shubham.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDarkMode = theme.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: _buildMenu(context, theme, isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'KronoCam',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLiveLocation ? Icons.location_on : Icons.location_off,
            ),
            tooltip: 'Show location',
            color: _showLiveLocation ? ThemeProvider.accent : null,
            onPressed: _toggleLiveLocation,
          ),
          Builder(
            builder:
                (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
          ),
        ],
      ),
      body: OrientationBuilder(
        builder:
            (context, orientation) => Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraPreview(),
                if (_showLiveLocation && _liveLocation != null)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        final position = Offset(
                          _overlayFraction.dx * size.width,
                          _overlayFraction.dy * size.height,
                        );
                        return Stack(
                          children: [
                            Positioned(
                              left: position.dx,
                              top: position.dy,
                              child: GestureDetector(
                                onTap: _openPreviewSettings,
                                onPanUpdate: (details) {
                                  setState(() {
                                    _overlayFraction = Offset(
                                      (_overlayFraction.dx +
                                              details.delta.dx / size.width)
                                          .clamp(0.0, 0.95),
                                      (_overlayFraction.dy +
                                              details.delta.dy / size.height)
                                          .clamp(0.0, 0.95),
                                    );
                                  });
                                },
                                child: Transform.rotate(
                                  angle: _overlayRotation,
                                  child: RepaintBoundary(
                                    child: ValueListenableBuilder<StampConfig>(
                                      valueListenable: _stampNotifier,
                                      builder:
                                          (context, config, _) =>
                                              StampOverlay(config: config),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (orientation == Orientation.landscape)
                  Positioned(
                    top: 0,
                    right: 12,
                    bottom: 0,
                    child: _buildLandscapeControls(),
                  )
                else
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28,
                    child: Center(child: _buildShutter()),
                  ),
                if (_lastCapturedFile != null)
                  Positioned(
                    left: orientation == Orientation.landscape ? 20 : 20,
                    bottom: orientation == Orientation.landscape ? 20 : 40,
                    child: GestureDetector(
                      onTap: () => _openEditor(_lastCapturedFile!),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white70, width: 1.5),
                          image: DecorationImage(
                            image: FileImage(_lastCapturedFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _cameraError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_controller == null || _initFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _zoomStart = _zoomLevel,
          onScaleUpdate: (details) {
            if (details.scale == 1 || _maxZoom <= _minZoom) return;
            final nextZoom = (_zoomStart * details.scale).clamp(
              _minZoom,
              _maxZoom,
            );
            if ((nextZoom - _zoomLevel).abs() < 0.01) return;
            _zoomLevel = nextZoom;
            _controller?.setZoomLevel(nextZoom);
            if (mounted) setState(() {});
          },
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: _controller!.value.previewSize?.height ?? 1,
                height: _controller!.value.previewSize?.width ?? 1,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShutter() => GestureDetector(
    onTap: _capture,
    child: Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _capturing ? Colors.white38 : ThemeProvider.accent,
        ),
      ),
    ),
  );

  Widget _buildLandscapeControls() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      AnimatedRotation(
        turns: 0.25,
        duration: const Duration(milliseconds: 220),
        child: IconButton(
          onPressed: _toggleLiveLocation,
          icon: Icon(
            _showLiveLocation ? Icons.location_on : Icons.location_off,
          ),
          color: _showLiveLocation ? ThemeProvider.accent : Colors.white,
        ),
      ),
      const SizedBox(height: 16),
      _buildShutter(),
      const SizedBox(height: 16),
      AnimatedRotation(
        turns: 0.25,
        duration: const Duration(milliseconds: 220),
        child: Builder(
          builder:
              (context) => IconButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.settings_outlined),
                color: Colors.white,
              ),
        ),
      ),
    ],
  );

  Widget _buildMenu(
    BuildContext context,
    ThemeProvider theme,
    bool isDarkMode,
  ) {
    final bg = isDarkMode ? const Color(0xFF141416) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: ThemeProvider.accent,
                    child: const Icon(Icons.camera_alt, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'KronoCam',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Upload Photo'),
              subtitle: const Text('Pick a photo from gallery to edit'),
              onTap: _uploadPhoto,
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Modify Date / Time / Day'),
              subtitle: const Text('Edit your stamp after watching an ad'),
              onTap: _modifyLatest,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share App'),
              subtitle: const Text('Share KronoCam with another app'),
              onTap: () {
                Navigator.pop(context);
                _shareApp();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode_outlined,
              ),
              title: const Text('Dark Theme'),
              trailing: Switch(
                value: isDarkMode,
                activeThumbColor: ThemeProvider.accent,
                onChanged: (v) => theme.setDarkMode(v),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
