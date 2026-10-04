class AuthConfig {
  const AuthConfig({
    this.googleEnabled = false,
    this.googleClientId,
    this.appleEnabled = false,
    this.appleBundleId,
    this.otpEnabled = false,
  });

  final bool googleEnabled;
  final String? googleClientId;
  final bool appleEnabled;
  final String? appleBundleId;
  final bool otpEnabled;

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    final google = json['google'] is Map ? json['google'] as Map<String, dynamic> : null;
    final apple = json['apple'] is Map ? json['apple'] as Map<String, dynamic> : null;
    final otp = json['whatsapp_otp'] is Map ? json['whatsapp_otp'] as Map<String, dynamic> : null;

    return AuthConfig(
      googleEnabled: google?['enabled'] == true,
      googleClientId: google?['client_id'] as String?,
      appleEnabled: apple?['enabled'] == true,
      appleBundleId: apple?['bundle_id'] as String?,
      otpEnabled: otp?['enabled'] == true,
    );
  }

  static const empty = AuthConfig();
}
