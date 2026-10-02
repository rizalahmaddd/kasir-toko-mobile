import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_storage.dart';

/// Hosted (SaaS) builds pin API_BASE_URL with --dart-define=HOSTED=true: every shop shares that
/// server, so the address field disappears and new shops can sign up from the app.
const isHosted = bool.fromEnvironment('HOSTED');

const productionServerUrl = 'https://kasirtoko.biz.id';

const _defaultServerUrl = String.fromEnvironment('API_BASE_URL', defaultValue: isHosted ? productionServerUrl : '');

/// The store's Laravel server. Self-hosted shops run it on the LAN, so outside hosted builds the
/// address is set on the login screen instead of being baked into the build.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);

class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() {
    if (isHosted) {
      return normalize(_defaultServerUrl);
    }

    return ref.read(sharedPreferencesProvider).getString(StorageKeys.serverUrl) ?? _defaultServerUrl;
  }

  Future<void> save(String url) async {
    if (isHosted) {
      return;
    }

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
