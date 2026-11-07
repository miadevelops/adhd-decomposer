import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for capturing widgets as images and sharing them
class ShareService {
  /// Renders the widget behind [key] to PNG bytes. Call this while the widget
  /// is still on screen (e.g. before closing the sheet that shows it).
  static Future<Uint8List?> capture(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture at 3x resolution for high quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Share capture error: $e');
      return null;
    }
  }

  /// Shares [imageBytes] (or just the text if there is no image or saving it
  /// fails). Returns true unless the user dismissed the share sheet.
  static Future<bool> share({
    Uint8List? imageBytes,
    required String shareText,
    String? subject,
  }) async {
    ShareResult result;
    try {
      if (imageBytes == null || kIsWeb) {
        throw Exception('No image to share');
      }
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/tiny_steps_share_$timestamp.png');
      await file.writeAsBytes(imageBytes);

      result = await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: subject,
      );

      // Clean up after a delay
      Future.delayed(const Duration(minutes: 1), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    } catch (e) {
      debugPrint('Share error: $e');
      // Fallback to text-only share
      result = await Share.share(shareText, subject: subject);
    }
    return result.status != ShareResultStatus.dismissed;
  }

  /// Capture a widget using a GlobalKey and share it
  static Future<bool> captureAndShare({
    required GlobalKey key,
    required String shareText,
    String? subject,
  }) async {
    final bytes = await capture(key);
    return share(imageBytes: bytes, shareText: shareText, subject: subject);
  }
  
  /// Share text only (fallback)
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
