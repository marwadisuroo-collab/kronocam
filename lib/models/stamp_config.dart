import 'package:flutter/material.dart';

enum StampPosition { bottomLeft, bottomCenter, bottomRight }

enum StampLayout { portrait, landscape }

class StampConfig {
  bool showDate;
  bool showTime;
  bool showDay;
  String projectName;
  DateTime dateTime;
  StampPosition position;
  Color textColor;
  Color backgroundColor;
  String fontFamily;
  double textSize;
  bool withBackground;
  bool showLocation;
  double? latitude;
  double? longitude;
  String? address;
  double boxScale;
  StampLayout layout;

  StampConfig({
    this.showDate = true,
    this.showTime = true,
    this.showDay = true,
    this.projectName = '',
    DateTime? dateTime,
    this.position = StampPosition.bottomLeft,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0x73000000),
    this.fontFamily = 'monospace',
    this.textSize = 13,
    this.withBackground = true,
    this.showLocation = false,
    this.latitude,
    this.longitude,
    this.address,
    this.boxScale = 1,
    this.layout = StampLayout.portrait,
  }) : dateTime = dateTime ?? DateTime.now();

  StampConfig copyWith({
    bool? showDate,
    bool? showTime,
    bool? showDay,
    String? projectName,
    DateTime? dateTime,
    StampPosition? position,
    Color? textColor,
    Color? backgroundColor,
    String? fontFamily,
    double? textSize,
    bool? withBackground,
    bool? showLocation,
    double? latitude,
    double? longitude,
    String? address,
    double? boxScale,
    StampLayout? layout,
  }) {
    return StampConfig(
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showDay: showDay ?? this.showDay,
      projectName: projectName ?? this.projectName,
      dateTime: dateTime ?? this.dateTime,
      position: position ?? this.position,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      textSize: textSize ?? this.textSize,
      withBackground: withBackground ?? this.withBackground,
      showLocation: showLocation ?? this.showLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      boxScale: boxScale ?? this.boxScale,
      layout: layout ?? this.layout,
    );
  }
}
