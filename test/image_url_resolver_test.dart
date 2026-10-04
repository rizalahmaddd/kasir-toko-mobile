import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/core/utils/image_url_resolver.dart';

void main() {
  group('resolveImageUrl', () {
    test('returns null for null or empty input', () {
      expect(resolveImageUrl(null, 'http://192.168.1.100:8000'), isNull);
      expect(resolveImageUrl('', 'http://192.168.1.100:8000'), isNull);
      expect(resolveImageUrl('   ', 'http://192.168.1.100:8000'), isNull);
    });

    test('rewrites localhost to serverUrl host and port', () {
      const server = 'http://192.168.1.100:8000';
      const input = 'http://localhost:8000/storage/products/air-mineral-600ml.jpg';
      expect(
        resolveImageUrl(input, server),
        'http://192.168.1.100:8000/storage/products/air-mineral-600ml.jpg',
      );
    });

    test('rewrites 127.0.0.1 to emulator host', () {
      const server = 'http://10.0.2.2:8000';
      const input = 'http://127.0.0.1:8000/storage/products/air-mineral-600ml.jpg';
      expect(
        resolveImageUrl(input, server),
        'http://10.0.2.2:8000/storage/products/air-mineral-600ml.jpg',
      );
    });

    test('prepends serverUrl to relative path', () {
      const server = 'http://192.168.1.50:8000';
      const input = '/storage/products/beras-premium-5kg.jpg';
      expect(
        resolveImageUrl(input, server),
        'http://192.168.1.50:8000/storage/products/beras-premium-5kg.jpg',
      );
    });

    test('preserves external CDN URLs', () {
      const server = 'http://192.168.1.50:8000';
      const input = 'https://images.unsplash.com/photo-12345?w=500';
      expect(
        resolveImageUrl(input, server),
        'https://images.unsplash.com/photo-12345?w=500',
      );
    });
  });
}
