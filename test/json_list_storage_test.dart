import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:adhd_decomposer/data/services/json_list_storage.dart';

Map<String, dynamic> _id(Map<String, dynamic> m) => m;

void main() {
  group('JsonListStorage', () {
    test('round-trips text that contains the legacy separator', () {
      final items = [
        {'title': 'a ||| b'},
        {'title': 'plain'},
      ];
      final encoded = JsonListStorage.encode(items, _id);
      expect(JsonListStorage.decode(encoded, _id), items);
    });

    test('reads the legacy ||| format', () {
      final legacy = [
        jsonEncode({'title': 'one'}),
        jsonEncode({'title': 'two'}),
      ].join('|||');
      final decoded = JsonListStorage.decode(legacy, _id);
      expect(decoded.map((m) => m['title']), ['one', 'two']);
    });

    test('recovers legacy items whose text contained |||', () {
      final legacy = [
        jsonEncode({'title': 'before ||| after'}),
        jsonEncode({'title': 'next'}),
      ].join('|||');
      final decoded = JsonListStorage.decode(legacy, _id);
      expect(decoded.map((m) => m['title']), ['before ||| after', 'next']);
    });

    test('reports unreadable items without dropping readable ones', () {
      final errors = <Object>[];
      final legacy = '{broken|||${jsonEncode({'title': 'ok'})}';
      final decoded =
          JsonListStorage.decode(legacy, _id, onItemError: errors.add);
      expect(decoded.map((m) => m['title']), ['ok']);
      expect(errors, isNotEmpty);
    });
  });
}
