# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core (deferred components referenced by the Flutter embedding)
-dontwarn com.google.android.play.core.**

# Bluetooth thermal printer: keep the socket classes it opens at runtime.
-keep class app.web.groons.print_bluetooth_thermal.** { *; }

# mobile_scanner (ML Kit barcode)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
