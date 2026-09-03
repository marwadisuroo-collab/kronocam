import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../provider/theme_provider.dart';
import '../services/gallery_service.dart';
import '../services/location_service.dart';
import 'edit_screen.dart';
import 'privacy_policy_screen.dart';

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

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
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
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initFuture = _controller!.initialize();
      await _initFuture;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
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
      final file = File(xfile.path);
      final bytes = await file.readAsBytes();

      // Save the CLEAN photo (no stamp) straight to the gallery.
      final saved = await GalleryService.saveBytes(
        bytes,
        name: 'KronoCam_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() => _lastCapturedFile = file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Photo saved' : 'Photo captured (save failed)',
          ),
          action: SnackBarAction(
            label: 'Add Stamp',
            onPressed: () => _openEditor(file),
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

  void _openEditor(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(imageFile: file)),
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
        const SnackBar(content: Text('Location unavailable or permission denied.')),
      );
      return;
    }
    setState(() {
      _liveLocation = result;
      _showLiveLocation = true;
    });
  }

  Future<void> _shareApp() async {
    try {
      final apkPath = await MethodChannel('com.kronocam.app/share_apk')
          .invokeMethod<String>('getApkPath');
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
      ShareParams(text: 'Try KronoCam - Timestamp Camera.'),
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
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          if (_showLiveLocation && _liveLocation != null)
            Positioned(
              left: 18,
              top: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                    child: Text(
                      'Latitude: ${_liveLocation!.latitude.toStringAsFixed(5)}°\n'
                      'Longitude: ${_liveLocation!.longitude.toStringAsFixed(5)}°',
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: GestureDetector(
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
                      color: _capturing
                          ? Colors.white38
                          : ThemeProvider.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_lastCapturedFile != null)
            Positioned(
              left: 20,
              bottom: 40,
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
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
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

  Widget _buildMenu(BuildContext context, ThemeProvider theme, bool isDarkMode) {
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
              subtitle: const Text('Edit the stamp on your latest photo'),
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
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
