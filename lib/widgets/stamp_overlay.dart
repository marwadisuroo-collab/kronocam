import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stamp_config.dart';

class StampOverlay extends StatelessWidget {
  final StampConfig config;

  const StampOverlay({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];

    if (config.projectName.trim().isNotEmpty) {
      lines.add('Project Name: ${config.projectName.trim()}');
    }

    if (config.showLocation && config.address?.trim().isNotEmpty == true) {
      lines.add('Address: ${config.address!.trim()}');
    }

    if (config.showLocation &&
        config.latitude != null &&
        config.longitude != null) {
      lines.add('Latitude: ${config.latitude!.toStringAsFixed(5)}°');
      lines.add('Longitude: ${config.longitude!.toStringAsFixed(5)}°');
    }

    final dateLine = <String>[];
    if (config.showDay) {
      dateLine.add(DateFormat('EEEE').format(config.dateTime));
    }
    if (config.showDate) {
      dateLine.add(DateFormat('dd/MM/yyyy').format(config.dateTime));
    }
    if (config.showTime) {
      dateLine.add(DateFormat('hh:mm a').format(config.dateTime));
    }
    if (dateLine.isNotEmpty) lines.add(dateLine.join('  '));

    if (lines.isEmpty) return const SizedBox.shrink();

    Alignment alignment;
    CrossAxisAlignment crossAlign;
    switch (config.position) {
      case StampPosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        crossAlign = CrossAxisAlignment.start;
        break;
      case StampPosition.bottomCenter:
        alignment = Alignment.bottomCenter;
        crossAlign = CrossAxisAlignment.center;
        break;
      case StampPosition.bottomRight:
        alignment = Alignment.bottomRight;
        crossAlign = CrossAxisAlignment.end;
        break;
    }

    final textWidgets = lines.map((line) {
      final isProjectName = line.startsWith('Project Name:');
      return Text(
        line,
        textAlign: crossAlign == CrossAxisAlignment.start
            ? TextAlign.left
            : crossAlign == CrossAxisAlignment.end
                ? TextAlign.right
                : TextAlign.center,
        style: TextStyle(
          color: config.textColor,
          fontSize: 15,
          fontFamily: 'monospace',
          fontWeight: isProjectName ? FontWeight.w700 : FontWeight.w400,
          shadows: config.withBackground
              ? null
              : const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
      );
    }).toList();

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: config.withBackground
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : EdgeInsets.zero,
        decoration: config.withBackground
            ? BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Column(
          crossAxisAlignment: crossAlign,
          mainAxisSize: MainAxisSize.min,
          children: textWidgets,
        ),
      ),
    );
  }
}
