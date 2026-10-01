import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config.dart';
import '../storage/app_storage.dart';

/// Last good API responses kept on the device for when the server can't be reached.
/// Entries are tagged with the server they came from so switching stores never mixes data.
final offlineCacheProvider = Provider<OfflineCache>((ref) => OfflineCache(ref.watch(sharedPreferencesProvider), ref.watch(serverUrlProvider)));

class OfflineCache {
  OfflineCache(this._prefs, this._server);

  final SharedPreferences _prefs;
  final String _server;

  String _key(String name) => 'offline_$name';

  Future<void> put(String name, Object? value) =>
      _prefs.setString(_key(name), jsonEncode({'server': _server, 'saved_at': DateTime.now().toIso8601String(), 'value': value}));

  dynamic get(String name) {
    final raw = _prefs.getString(_key(name));
    if (raw == null) {
      return null;
    }
    final entry = jsonDecode(raw) as Map<String, dynamic>;

    return entry['server'] == _server ? entry['value'] : null;
  }

  Future<File> _file(String name) async => File('${(await getApplicationSupportDirectory()).path}/$name.json');

  Future<void> writeFile(String name, Object value) async {
    final file = await _file(name);
    await file.writeAsString(jsonEncode({'server': _server, 'value': value}), flush: true);
  }

  Future<dynamic> readFile(String name) async {
    final file = await _file(name);
    if (!await file.exists()) {
      return null;
    }
    try {
      final entry = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return entry['server'] == _server ? entry['value'] : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((key) => key.startsWith('offline_'))) {
      await _prefs.remove(key);
    }
    final file = await _file('catalog');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
