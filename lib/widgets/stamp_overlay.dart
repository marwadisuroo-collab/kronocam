import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stamp_config.dart';

class StampOverlay extends StatelessWidget {
  final StampConfig config;

  const StampOverlay({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final lines = <String>[];

    lines.add('Project: ${config.projectName.trim()}');

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

    final textWidgets =
        lines
            .map(
              (line) => Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign:
                    crossAlign == CrossAxisAlignment.start
                        ? TextAlign.left
                        : crossAlign == CrossAxisAlignment.end
                        ? TextAlign.right
                        : TextAlign.center,
                style: TextStyle(
                  color: config.textColor,
                  fontSize: isLandscape ? 12 : 13,
                  fontFamily: 'monospace',
                  fontWeight:
                      line.startsWith('Project:')
                          ? FontWeight.w700
                          : FontWeight.w400,
                  shadows:
                      config.withBackground
                          ? null
                          : const [
                            Shadow(color: Colors.black87, blurRadius: 6),
                          ],
                ),
              ),
            )
            .toList();

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: isLandscape ? 330 : 300),
        margin: EdgeInsets.all(isLandscape ? 12 : 18),
        padding:
            config.withBackground
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : EdgeInsets.zero,
        decoration:
            config.withBackground
                ? BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                )
                : null,
        child: Column(
          crossAxisAlignment: crossAlign,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(
                  'Kronocam',
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: isLandscape ? 12 : 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ...textWidgets,
          ],
        ),
      ),
    );
  }
}
