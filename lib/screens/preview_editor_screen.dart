import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../models/stamp_config.dart';
import '../services/gallery_service.dart';
import '../services/location_service.dart';
import '../widgets/stamp_overlay.dart';
import 'map_screen.dart';

Map<String, dynamic> _loadPhotoInIsolate(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  final upright = decoded == null ? null : img.bakeOrientation(decoded);
  return {
    'bytes': bytes,
    'aspectRatio': upright == null ? 3 / 4 : upright.width / upright.height,
  };
}

Uint8List compositePreviewInIsolate(Map<String, dynamic> input) {
  final photo = img.decodeImage(input['photo'] as Uint8List);
  final overlay = img.decodeImage(input['overlay'] as Uint8List);
  if (photo == null || overlay == null) return input['photo'] as Uint8List;

  final uprightPhoto = img.bakeOrientation(photo);
  final displayWidth = input['displayWidth'] as double;
  final pixelRatio = input['pixelRatio'] as double;
  final scale = uprightPhoto.width / (displayWidth * pixelRatio);
  final boxScale = input['boxScale'] as double;
  final rotation = input['rotation'] as double;
  final overlayWidth = math.max(1, (overlay.width * scale * boxScale).round());
  final overlayHeight = math.max(
    1,
    (overlay.height * scale * boxScale).round(),
  );
  final resizedOverlay = img.copyResize(
    overlay,
    width: overlayWidth,
    height: overlayHeight,
    interpolation: img.Interpolation.cubic,
  );
  final rotatedOverlay = img.copyRotate(
    resizedOverlay,
    angle: rotation * 180 / math.pi,
    interpolation: img.Interpolation.cubic,
  );
  final finalWidth = rotatedOverlay.width;
  final finalHeight = rotatedOverlay.height;
  final x =
      ((input['ratioX'] as double) * uprightPhoto.width)
          .round()
          .clamp(0, math.max(0, uprightPhoto.width - finalWidth))
          .toInt();
  final y =
      ((input['ratioY'] as double) * uprightPhoto.height)
          .round()
          .clamp(0, math.max(0, uprightPhoto.height - finalHeight))
          .toInt();
  img.compositeImage(uprightPhoto, rotatedOverlay, dstX: x, dstY: y);
  return Uint8List.fromList(img.encodeJpg(uprightPhoto, quality: 95));
}

class PreviewEditorScreen extends StatefulWidget {
  final String imagePath;
  final StampConfig initialConfig;
  final Offset initialPosition;
  final VoidCallback? onSaveStarted;

  const PreviewEditorScreen({
    super.key,
    required this.imagePath,
    required this.initialConfig,
    required this.initialPosition,
    this.onSaveStarted,
  });

  @override
  State<PreviewEditorScreen> createState() => _PreviewEditorScreenState();
}

class _PreviewEditorScreenState extends State<PreviewEditorScreen> {
  final GlobalKey _overlayKey = GlobalKey();
  late StampConfig _config;
  late Offset _position;
  double _rotation = 0;
  double _gestureScale = 1;
  double _gestureRotation = 0;
  Offset _gesturePosition = Offset.zero;
  Uint8List? _photoBytes;
  double _aspectRatio = 3 / 4;
  double _displayWidth = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _position = widget.initialPosition;
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final loaded = await compute(_loadPhotoInIsolate, widget.imagePath);
    if (!mounted) return;
    setState(() {
      _photoBytes = loaded['bytes'] as Uint8List;
      _aspectRatio = loaded['aspectRatio'] as double;
    });
  }

  Future<void> _savePhoto() async {
    if (_photoBytes == null || _saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _overlayKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return;
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final overlayImage = await boundary.toImage(pixelRatio: pixelRatio);
      final overlayData = await overlayImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (overlayData == null) return;
      final input = <String, dynamic>{
        'photo': _photoBytes!,
        'overlay': overlayData.buffer.asUint8List(),
        'displayWidth': _displayWidth,
        'pixelRatio': pixelRatio,
        'boxScale': _config.boxScale,
        'rotation': _rotation,
        'ratioX': _position.dx,
        'ratioY': _position.dy,
      };
      widget.onSaveStarted?.call();
      if (mounted) Navigator.pop(context);
      unawaited(_finishSave(input));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishSave(Map<String, dynamic> input) async {
    final output = await compute(compositePreviewInIsolate, input);
    await GalleryService.saveBytes(
      output,
      name: 'KronoCam_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _openSettings() async {
    final projectController = TextEditingController(text: _config.projectName);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (modalContext) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.viewInsetsOf(modalContext).bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
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
                            labelText: 'Project Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Box Size'),
                            Expanded(
                              child: Slider(
                                min: 0.55,
                                max: 1.8,
                                divisions: 25,
                                value: _config.boxScale,
                                label: '${(_config.boxScale * 100).round()}%',
                                onChanged: (value) {
                                  setState(
                                    () =>
                                        _config = _config.copyWith(
                                          boxScale: value,
                                        ),
                                  );
                                  setModalState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SegmentedButton<StampLayout>(
                          segments: const [
                            ButtonSegment(
                              value: StampLayout.portrait,
                              label: Text('Portrait Style'),
                              icon: Icon(Icons.stay_current_portrait),
                            ),
                            ButtonSegment(
                              value: StampLayout.landscape,
                              label: Text('Landscape Style'),
                              icon: Icon(Icons.stay_current_landscape),
                            ),
                          ],
                          selected: {_config.layout},
                          onSelectionChanged: (value) {
                            setState(
                              () =>
                                  _config = _config.copyWith(
                                    layout: value.first,
                                  ),
                            );
                            setModalState(() {});
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month),
                          title: const Text('Modify Date and Time'),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: modalContext,
                              initialDate: _config.dateTime,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date == null || !modalContext.mounted) return;
                            final time = await showTimePicker(
                              context: modalContext,
                              initialTime: TimeOfDay.fromDateTime(
                                _config.dateTime,
                              ),
                            );
                            if (time == null) return;
                            setState(
                              () =>
                                  _config = _config.copyWith(
                                    dateTime: DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    ),
                                  ),
                            );
                            setModalState(() {});
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: const Text('Change Location via Map'),
                          subtitle: Text(
                            _config.address ?? 'Use current location',
                          ),
                          onTap: () async {
                            final location =
                                await Navigator.push<LocationResult>(
                                  modalContext,
                                  MaterialPageRoute(
                                    builder: (_) => MapScreen(),
                                  ),
                                );
                            if (location == null || !mounted) return;
                            setState(
                              () =>
                                  _config = _config.copyWith(
                                    showLocation: true,
                                    latitude: location.latitude,
                                    longitude: location.longitude,
                                    address: location.address,
                                  ),
                            );
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              setState(
                                () =>
                                    _config = _config.copyWith(
                                      projectName: projectController.text,
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
          ),
    );
    projectController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview Editor'),
        actions: [
          TextButton.icon(
            onPressed:
                _saving || _photoBytes == null
                    ? null
                    : () {
                      _savePhoto();
                    },
            icon:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_alt),
            label: const Text('Save Photo'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * _aspectRatio,
                  );
                  final height = width / _aspectRatio;
                  _displayWidth = width;
                  return SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_photoBytes == null)
                          Image.file(File(widget.imagePath), fit: BoxFit.fill)
                        else
                          Image.memory(_photoBytes!, fit: BoxFit.fill),
                        Positioned(
                          left: _position.dx * width,
                          top: _position.dy * height,
                          child: GestureDetector(
                            onTap: _openSettings,
                            onScaleStart: (details) {
                              _gestureScale = _config.boxScale;
                              _gestureRotation = _rotation;
                              _gesturePosition = _position;
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _position = Offset(
                                  (_gesturePosition.dx +
                                          details.focalPointDelta.dx / width)
                                      .clamp(0.0, 1.0),
                                  (_gesturePosition.dy +
                                          details.focalPointDelta.dy / height)
                                      .clamp(0.0, 1.0),
                                );
                                _config = _config.copyWith(
                                  boxScale: (_gestureScale * details.scale)
                                      .clamp(0.25, 3.0),
                                );
                                _rotation = _gestureRotation + details.rotation;
                              });
                            },
                            child: Transform.rotate(
                              angle: _rotation,
                              alignment: Alignment.topLeft,
                              child: Transform.scale(
                                scale: _config.boxScale,
                                alignment: Alignment.topLeft,
                                child: RepaintBoundary(
                                  key: _overlayKey,
                                  child: StampOverlay(
                                    config: _config.copyWith(boxScale: 1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _saving || _photoBytes == null
                          ? null
                          : () {
                            _savePhoto();
                          },
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save Photo'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
