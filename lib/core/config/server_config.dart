import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_storage.dart';

const _defaultServerUrl = String.fromEnvironment('API_BASE_URL');

/// The store's own Laravel server. Most shops self-host on the LAN, so the address is set on the
/// login screen instead of being baked into the build.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);

class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(sharedPreferencesProvider).getString(StorageKeys.serverUrl) ?? _defaultServerUrl;
  }

  Future<void> save(String url) async {
    final normalized = normalize(url);
    await ref.read(sharedPreferencesProvider).setString(StorageKeys.serverUrl, normalized);
    state = normalized;
  }

  static String normalize(String input) {
    var url = input.trim();

    if (url.isEmpty) {
      return url;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    url = url.replaceAll(RegExp(r'/+$'), '');

    return url.replaceAll(RegExp(r'/api(/v1)?$'), '');
  }
}
