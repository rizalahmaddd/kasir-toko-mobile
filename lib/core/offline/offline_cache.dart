import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config.dart';
import '../storage/app_storage.dart';

/// Shop of the signed-in account; overridden in main() so this file stays free of feature imports.
final offlineTenantProvider = Provider<int?>((ref) => null);

/// Last good API responses kept on the device for when the server can't be reached.
/// Entries are tagged with the server and the shop they came from: on a hosted server many shops
/// share one address, so the server alone would let one shop read another's cached catalog.
final offlineCacheProvider = Provider<OfflineCache>(
  (ref) => OfflineCache(ref.watch(sharedPreferencesProvider), '${ref.watch(serverUrlProvider)}#${ref.watch(offlineTenantProvider) ?? ''}'),
);

class OfflineCache {
  OfflineCache(this._prefs, this._server);

  final SharedPreferences _prefs;
  final String _server;

  // Own prefix: the offline sales queue also lives under "offline_" and must survive clear().
  static const _prefix = 'offline_cache_';

  String _key(String name) => '$_prefix$name';

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

  static const _maxResponses = 400;
  static int _writesSincePrune = 0;

  Future<Directory> _responsesDir() async => Directory('${(await getApplicationSupportDirectory()).path}/responses');

  // FNV-1a: a stable, filesystem-safe name for any request key, whatever its length.
  String _hash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode('$_server|$input')) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  final Map<String, dynamic> _memoryResponses = {};

  /// Keeps the body of a successful GET so the same screen can still open without the server.
  Future<void> putResponse(String key, Object? body) async {
    _memoryResponses[key] = body;
    try {
      final dir = await _responsesDir();
      await dir.create(recursive: true);
      await File('${dir.path}/${_hash(key)}.json').writeAsString(jsonEncode({'server': _server, 'key': key, 'value': body}), flush: true);
      if (++_writesSincePrune >= 25) {
        _writesSincePrune = 0;
        await _prune(dir);
      }
    } on Object {
      // A full disk or missing storage plugin only costs the offline copy, never the request itself.
    }
  }

  Future<dynamic> getResponse(String key) async {
    if (_memoryResponses.containsKey(key)) {
      return _memoryResponses[key];
    }
    try {
      final file = File('${(await _responsesDir()).path}/${_hash(key)}.json');
      if (!await file.exists()) {
        return null;
      }
      final entry = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final val = entry['server'] == _server && entry['key'] == key ? entry['value'] : null;
      if (val != null) {
        _memoryResponses[key] = val;
      }
      return val;
    } on Object {
      return null;
    }
  }

  Future<void> removeResponse(String key) async {
    _memoryResponses.remove(key);
    try {
      final file = File('${(await _responsesDir()).path}/${_hash(key)}.json');
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Ignored: file might not exist or cannot be deleted
    }
  }

  /// Search terms and filters each get their own entry, so drop the least recently written ones.
  Future<void> _prune(Directory dir) async {
    final files = await dir.list().where((entity) => entity is File).cast<File>().toList();
    if (files.length <= _maxResponses) {
      return;
    }
    final dated = [for (final file in files) (file: file, modified: await file.lastModified())]..sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in dated.take(files.length - _maxResponses)) {
      await entry.file.delete();
    }
  }

  Future<void> clear() async {
    _memoryResponses.clear();
    for (final key in _prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      await _prefs.remove(key);
    }
    final file = await _file('catalog');
    if (await file.exists()) {
      await file.delete();
    }
    final responses = await _responsesDir();
    if (await responses.exists()) {
      await responses.delete(recursive: true);
    }
  }
}
