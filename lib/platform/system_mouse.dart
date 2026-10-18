import 'dart:io';

import 'package:flutter/services.dart';

/// macOS-only bridge for the optional system-mouse AI takeover demo.
///
/// The native side asks for the macOS Accessibility permission and posts a
/// real `CGEvent` click at the given global Flutter coordinates.
class SystemMouse {
  static const MethodChannel _channel = MethodChannel('yijing/mouse');

  static bool get supported => Platform.isMacOS;

  static Future<bool> isTrusted() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isTrusted') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the macOS Accessibility prompt on first use.
  static Future<bool> requestTrust() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestTrust') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true when the native click was posted.
  static Future<bool> click(Offset point) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('click', {
            'x': point.dx,
            'y': point.dy,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
