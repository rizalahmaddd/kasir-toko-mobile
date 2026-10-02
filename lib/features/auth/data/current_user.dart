class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.phone,
    required this.roles,
    required this.permissions,
    required this.isSuperadmin,
    required this.enabledFeatures,
    this.tenant,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        roles: (json['roles'] as List? ?? const []).cast<String>(),
        permissions: (json['permissions'] as List? ?? const []).cast<String>().toSet(),
        isSuperadmin: json['is_superadmin'] as bool? ?? false,
        enabledFeatures: (json['enabled_features'] as List? ?? const []).cast<String>().toSet(),
        tenant: json['tenant'] is Map<String, dynamic> ? TenantInfo.fromJson(json['tenant'] as Map<String, dynamic>) : null,
      );

  final int id;
  final String name;
  final String username;
  final String? email;
  final String? phone;
  final List<String> roles;
  final Set<String> permissions;
  final bool isSuperadmin;
  final Set<String> enabledFeatures;

  /// Null on self-hosted servers older than multi-tenancy.
  final TenantInfo? tenant;

  bool get isTenantBlocked => tenant?.blockedReason != null;

  CurrentUser withTenant(TenantInfo? tenant) => CurrentUser(
        id: id,
        name: name,
        username: username,
        email: email,
        phone: phone,
        roles: roles,
        permissions: permissions,
        isSuperadmin: isSuperadmin,
        enabledFeatures: enabledFeatures,
        tenant: tenant,
      );

  bool can(String permission) => isSuperadmin || permissions.contains(permission);

  bool hasFeature(String feature) => enabledFeatures.contains(feature);

  String get roleLabel => roles.isEmpty ? '-' : roles.first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'roles': roles,
        'permissions': permissions.toList(),
        'is_superadmin': isSuperadmin,
        'enabled_features': enabledFeatures.toList(),
        'tenant': tenant?.toJson(),
      };
}

/// The shop an account belongs to, with its subscription state.
class TenantInfo {
  const TenantInfo({
    required this.id,
    required this.name,
    required this.plan,
    required this.planLabel,
    this.accessEndsAt,
    this.blockedReason,
    this.blockedMessage,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) => TenantInfo(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        planLabel: json['plan_label'] as String? ?? '',
        accessEndsAt: DateTime.tryParse(json['access_ends_at'] as String? ?? ''),
        blockedReason: json['blocked_reason'] as String?,
        blockedMessage: json['blocked_message'] as String?,
      );

  final int id;
  final String name;
  final String plan;
  final String planLabel;
  final DateTime? accessEndsAt;

  /// `tenant_suspended`, `trial_expired`, or `subscription_expired`; null while the shop can be used.
  final String? blockedReason;

  /// Server wording from the last 402 answer; /auth/me only sends the reason.
  final String? blockedMessage;

  bool get isTrial => plan == 'trial';

  TenantInfo blocked(String? reason, {String? message}) => TenantInfo(
        id: id,
        name: name,
        plan: plan,
        planLabel: planLabel,
        accessEndsAt: accessEndsAt,
        blockedReason: reason,
        blockedMessage: message,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'plan': plan,
        'plan_label': planLabel,
        'access_ends_at': accessEndsAt?.toIso8601String(),
        'blocked_reason': blockedReason,
        'blocked_message': blockedMessage,
      };
}
