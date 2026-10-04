import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config.dart';

/// Resolves product and asset image URLs against the store's configured server URL.
///
/// In self-hosted or local POS setups, Laravel's backend often returns:
/// - Absolute URLs with `http://localhost:8000` or `http://127.0.0.1:8000` from `APP_URL`
/// - Relative URLs like `/storage/products/xxx.jpg`
///
/// When running on a mobile device, tablet, or emulator, `localhost` points to the
/// device itself, not the PC hosting the backend. This resolver rewrites the host
/// and port to match the user's active [serverUrl], allowing photos to load smoothly.
String? resolveImageUrl(String? rawUrl, String serverUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return null;
  }

  final trimmed = rawUrl.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return trimmed;
  }

  final baseUri = Uri.tryParse(serverUrl);
  if (baseUri == null || baseUri.host.isEmpty) {
    return trimmed;
  }

  // 1. Relative path like '/storage/products/xyz.jpg'
  if (trimmed.startsWith('/') || !uri.hasScheme) {
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return baseUri.replace(path: cleanPath).toString();
  }

  // 2. Localhost or 127.0.0.1 emitted by Laravel
  if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
    return uri.replace(
      scheme: baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http',
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : (uri.hasPort ? uri.port : null),
    ).toString();
  }

  // 3. Otherwise return the remote URL (e.g. S3, CDN) as-is
  return trimmed;
}

/// Riverpod helper extension to resolve image URLs with the active server configuration.
extension ImageUrlResolverExtension on WidgetRef {
  String? resolveImage(String? rawUrl) {
    return resolveImageUrl(rawUrl, watch(serverUrlProvider));
  }
}
