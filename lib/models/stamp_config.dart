import 'package:flutter/material.dart';

enum StampPosition { bottomLeft, bottomCenter, bottomRight }

class StampConfig {
  bool showDate;
  bool showTime;
  bool showDay;
  String projectName;
  DateTime dateTime;
  StampPosition position;
  Color textColor;
  bool withBackground;
  bool showLocation;
  double? latitude;
  double? longitude;
  String? address;

  StampConfig({
    this.showDate = true,
    this.showTime = true,
    this.showDay = true,
    this.projectName = '',
    DateTime? dateTime,
    this.position = StampPosition.bottomLeft,
    this.textColor = Colors.white,
    this.withBackground = true,
    this.showLocation = false,
    this.latitude,
    this.longitude,
    this.address,
  }) : dateTime = dateTime ?? DateTime.now();

  StampConfig copyWith({
    bool? showDate,
    bool? showTime,
    bool? showDay,
    String? projectName,
    DateTime? dateTime,
    StampPosition? position,
    Color? textColor,
    bool? withBackground,
    bool? showLocation,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return StampConfig(
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showDay: showDay ?? this.showDay,
      projectName: projectName ?? this.projectName,
      dateTime: dateTime ?? this.dateTime,
      position: position ?? this.position,
      textColor: textColor ?? this.textColor,
      withBackground: withBackground ?? this.withBackground,
      showLocation: showLocation ?? this.showLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}
