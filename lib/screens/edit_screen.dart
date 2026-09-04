import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../models/stamp_config.dart';
import '../provider/theme_provider.dart';
import '../services/gallery_service.dart';
import '../services/image_orientation_service.dart';
import '../services/location_service.dart';
import '../widgets/stamp_overlay.dart';
import '../widgets/watch_ad_dialog.dart';

class EditScreen extends StatefulWidget {
  final File imageFile;
  final StampConfig? initialConfig;
  final bool autoSave;

  const EditScreen({
    super.key,
    required this.imageFile,
    this.initialConfig,
    this.autoSave = false,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _projectNameController = TextEditingController();

  late StampConfig _config;
  bool _unlocked = false;
  bool _saving = false;
  bool _loadingLocation = false;
  File? _displayImageFile;
  double _imageAspectRatio = 3 / 4;

  @override
  void dispose() {
    _projectNameController.dispose();
    final normalizedFile = _displayImageFile;
    if (normalizedFile != null &&
        normalizedFile.path != widget.imageFile.path) {
      normalizedFile.delete().ignore();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? StampConfig();
    _projectNameController.text = _config.projectName;
    _prepareImage();
  }

  Future<void> _prepareImage() async {
    try {
      final normalized = await ImageOrientationService.normalize(
        widget.imageFile,
      );
      if (!mounted) {
        normalized.file.delete().ignore();
        return;
      }
      setState(() {
        _displayImageFile = normalized.file;
        _imageAspectRatio = normalized.aspectRatio;
      });
      if (widget.autoSave) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _saveImage();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayImageFile = widget.imageFile;
        });
        if (widget.autoSave) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _saveImage();
          });
        }
      }
    }
  }

  void _requestUnlock() {
    showWatchAdToUnlockDialog(
      context,
      onUnlocked: () => setState(() => _unlocked = true),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _config.dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_config.dateTime),
    );
    if (time == null) return;
    setState(() {
      _config = _config.copyWith(
        dateTime: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    });
  }

  Future<void> _toggleLocation(bool enabled) async {
    if (!enabled) {
      setState(() => _config = _config.copyWith(showLocation: false));
      return;
    }

    setState(() => _loadingLocation = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _loadingLocation = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable or permission denied.'),
        ),
      );
      return;
    }

    setState(() {
      _config = _config.copyWith(
        showLocation: true,
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.address,
      );
    });
  }

  Future<void> _saveImage() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final ok = await GalleryService.saveBytes(
        bytes,
        name: 'KronoCam_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Saved to Gallery → KronoCam album'
                : 'Could not save photo. Check storage/photo permission.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDarkMode = theme.isDarkMode;
    final bg = isDarkMode ? const Color(0xFF0E0E10) : const Color(0xFFF3F4F6);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Edit Photo', style: TextStyle(color: textColor)),
        actions: [
          IconButton(
            icon:
                _saving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_alt),
            color: ThemeProvider.accent,
            onPressed: _saving ? null : _saveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: AspectRatio(
                  aspectRatio: _imageAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_displayImageFile == null)
                        const Center(child: CircularProgressIndicator())
                      else
                        Image.file(_displayImageFile!, fit: BoxFit.contain),
                      StampOverlay(config: _config),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildControls(isDarkMode, textColor),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDarkMode, Color textColor) {
    final cardColor = isDarkMode ? const Color(0xFF1A1A1C) : Colors.white;

    if (!_unlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              color: textColor.withValues(alpha: 0.5),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Stamp editor is locked',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Watch a short ad to modify date, time, day & project name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.accent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: _requestUnlock,
              icon: const Icon(Icons.ondemand_video),
              label: const Text('Watch Ad to Unlock'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _toggleChip('Day', _config.showDay, textColor, (v) {
                setState(() => _config = _config.copyWith(showDay: v));
              }),
              const SizedBox(width: 8),
              _toggleChip('Date', _config.showDate, textColor, (v) {
                setState(() => _config = _config.copyWith(showDate: v));
              }),
              const SizedBox(width: 8),
              _toggleChip('Time', _config.showTime, textColor, (v) {
                setState(() => _config = _config.copyWith(showTime: v));
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _toggleChip(
                _loadingLocation ? 'Getting location...' : 'Location',
                _config.showLocation,
                textColor,
                _toggleLocation,
              ),
              if (_config.showLocation && _config.address != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _config.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectNameController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Project Name (any language)',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              filled: true,
              fillColor:
                  isDarkMode
                      ? const Color(0xFF232326)
                      : const Color(0xFFF1F2F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged:
                (v) =>
                    setState(() => _config = _config.copyWith(projectName: v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Position',
                style: TextStyle(color: textColor, fontSize: 13),
              ),
              const SizedBox(width: 10),
              _positionButton(
                StampPosition.bottomLeft,
                Icons.align_horizontal_left,
              ),
              _positionButton(
                StampPosition.bottomCenter,
                Icons.align_horizontal_center,
              ),
              _positionButton(
                StampPosition.bottomRight,
                Icons.align_horizontal_right,
              ),
              const Spacer(),
              Text('Card bg', style: TextStyle(color: textColor, fontSize: 13)),
              Switch(
                value: _config.withBackground,
                activeThumbColor: ThemeProvider.accent,
                onChanged:
                    (v) => setState(
                      () => _config = _config.copyWith(withBackground: v),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _positionButton(StampPosition pos, IconData icon) {
    final selected = _config.position == pos;
    return IconButton(
      icon: Icon(icon),
      color: selected ? ThemeProvider.accent : Colors.grey,
      onPressed:
          () => setState(() => _config = _config.copyWith(position: pos)),
    );
  }

  Widget _toggleChip(
    String label,
    bool value,
    Color textColor,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: ThemeProvider.accent.withValues(alpha: 0.25),
      checkmarkColor: ThemeProvider.accent,
      labelStyle: TextStyle(color: textColor, fontSize: 12),
    );
  }
}
