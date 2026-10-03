class AuthConfig {
  const AuthConfig({
    this.googleEnabled = false,
    this.googleClientId,
    this.appleEnabled = false,
    this.appleBundleId,
  });

  final bool googleEnabled;
  final String? googleClientId;
  final bool appleEnabled;
  final String? appleBundleId;

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    final google = json['google'] is Map ? json['google'] as Map<String, dynamic> : null;
    final apple = json['apple'] is Map ? json['apple'] as Map<String, dynamic> : null;

    return AuthConfig(
      googleEnabled: google?['enabled'] == true,
      googleClientId: google?['client_id'] as String?,
      appleEnabled: apple?['enabled'] == true,
      appleBundleId: apple?['bundle_id'] as String?,
    );
  }

  static const empty = AuthConfig();
}
