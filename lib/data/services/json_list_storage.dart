import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores a list of JSON objects under a single Hive string key.
///
/// Data is written as a JSON array. Older builds joined items with `'|||'`,
/// which corrupted any item whose text contained that sequence; that legacy
/// format is still read (and rewritten as an array on the next save).
///
/// If anything can't be parsed, the raw value is copied to a backup key before
/// it can be overwritten, so a bad read never silently destroys user data.
class JsonListStorage {
  static const String legacySeparator = '|||';

  /// Decodes [raw] into its items, calling [fromJson] for each one.
  /// Items that fail to parse are skipped and reported via [onItemError].
  static List<T> decode<T>(
    String raw,
    T Function(Map<String, dynamic>) fromJson, {
    void Function(Object error)? onItemError,
  }) {
    final trimmed = raw.trimLeft();
    if (trimmed.isEmpty) return [];

    final List<Object?> rawItems;
    if (trimmed.startsWith('[')) {
      try {
        rawItems = jsonDecode(trimmed) as List<Object?>;
      } catch (e) {
        onItemError?.call(e);
        return [];
      }
    } else {
      rawItems = _decodeLegacy(raw, onItemError);
    }

    final result = <T>[];
    for (final item in rawItems) {
      try {
        result.add(fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (e) {
        onItemError?.call(e);
      }
    }
    return result;
  }

  /// Splits the legacy `'|||'` format. When a fragment isn't valid JSON on its
  /// own (because the item text contained the separator), following fragments
  /// are re-joined until it parses.
  static List<Object?> _decodeLegacy(
    String raw,
    void Function(Object error)? onItemError,
  ) {
    final parts = raw.split(legacySeparator);
    final items = <Object?>[];
    var i = 0;
    while (i < parts.length) {
      if (parts[i].isEmpty) {
        i++;
        continue;
      }
      var buffer = parts[i];
      var j = i;
      Object? decoded;
      while (true) {
        try {
          decoded = jsonDecode(buffer);
          break;
        } catch (_) {
          if (j + 1 >= parts.length) break;
          j++;
          buffer = '$buffer$legacySeparator${parts[j]}';
        }
      }
      if (decoded != null) {
        items.add(decoded);
        i = j + 1;
      } else {
        onItemError?.call(FormatException('Unreadable item', parts[i]));
        i++;
      }
    }
    return items;
  }

  static String encode<T>(
    Iterable<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) =>
      jsonEncode(items.map(toJson).toList());

  /// Loads a list from [box]/[key]. On any parse problem the original string
  /// is preserved under a timestamped backup key.
  static Future<List<T>> load<T>(
    Box<String> box,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = box.get(key);
    if (raw == null || raw.isEmpty) return [];

    var hadErrors = false;
    final items = decode<T>(raw, fromJson, onItemError: (e) {
      hadErrors = true;
      debugPrint('JsonListStorage: error parsing item in "$key": $e');
    });

    if (hadErrors) {
      final backupKey = '${key}_backup_${DateTime.now().millisecondsSinceEpoch}';
      await box.put(backupKey, raw);
      debugPrint('JsonListStorage: saved unreadable "$key" data to "$backupKey"');
    }
    return items;
  }
}
