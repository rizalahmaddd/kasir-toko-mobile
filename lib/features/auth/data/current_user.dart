import 'package:web_pos_mobile/core/constants/status_values.dart';

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

  /// Only the shop owner picks a store type; other roles go straight in while it is pending.
  bool get needsOnboarding => isSuperadmin && tenant != null && !tenant!.onboarded;

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

  bool get isPro => tenant?.isPro ?? true;

  bool get isTrial => tenant?.isTrial ?? false;

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
    this.isProExplicit,
    this.isTrialExplicit,
    this.trialEndsAt,
    this.accessEndsAt,
    this.blockedReason,
    this.blockedMessage,
    this.onboarded = true,
    this.storeType,
    this.renewal,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) => TenantInfo(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        planLabel: json['plan_label'] as String? ?? '',
        isProExplicit: json['is_pro'] as bool?,
        isTrialExplicit: json['is_trial'] as bool?,
        trialEndsAt: DateTime.tryParse(json['trial_ends_at'] as String? ?? ''),
        accessEndsAt: DateTime.tryParse(json['access_ends_at'] as String? ?? ''),
        blockedReason: json['blocked_reason'] as String?,
        blockedMessage: json['blocked_message'] as String?,
        onboarded: json['onboarded'] as bool? ?? true,
        storeType: json['store_type'] as String?,
        renewal: json['renewal'] is Map<String, dynamic> ? RenewalInfo.fromJson(json['renewal'] as Map<String, dynamic>) : null,
      );

  final int id;
  final String name;
  final String plan;
  final String planLabel;
  final bool? isProExplicit;
  final bool? isTrialExplicit;
  final DateTime? trialEndsAt;
  final DateTime? accessEndsAt;

  /// `tenant_suspended`, `trial_expired`, or `subscription_expired`; null while the shop can be used.
  final String? blockedReason;

  /// Server wording from the last 402 answer; /auth/me only sends the reason.
  final String? blockedMessage;

  /// Missing on servers that predate store presets, which never ask for onboarding.
  final bool onboarded;

  /// Key of the applied store preset, e.g. `kafe`; null when skipped or not chosen yet.
  final String? storeType;

  /// How to renew, sent by /auth/me only while the shop is blocked; null on older servers.
  final RenewalInfo? renewal;

  bool get isTrial => isTrialExplicit ?? (plan == PlanKinds.trial);

  bool get isPro => isProExplicit ?? (plan == PlanKinds.pro || isTrial);

  int? get daysUntilExpiration {
    if (accessEndsAt == null) return null;
    final now = DateTime.now();
    final diff = accessEndsAt!.difference(now);
    return diff.isNegative ? 0 : diff.inDays;
  }

  bool get isExpiringSoon {
    if (accessEndsAt == null || blockedReason != null) return false;
    final days = daysUntilExpiration;
    return days != null && days <= 5;
  }

  TenantInfo blocked(String? reason, {String? message}) => TenantInfo(
        id: id,
        name: name,
        plan: plan,
        planLabel: planLabel,
        isProExplicit: isProExplicit,
        isTrialExplicit: isTrialExplicit,
        trialEndsAt: trialEndsAt,
        accessEndsAt: accessEndsAt,
        blockedReason: reason,
        blockedMessage: message,
        onboarded: onboarded,
        storeType: storeType,
        renewal: renewal,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'plan': plan,
        'plan_label': planLabel,
        'is_pro': isPro,
        'is_trial': isTrial,
        'trial_ends_at': trialEndsAt?.toIso8601String(),
        'access_ends_at': accessEndsAt?.toIso8601String(),
        'blocked_reason': blockedReason,
        'blocked_message': blockedMessage,
        'onboarded': onboarded,
        'store_type': storeType,
        'renewal': renewal?.toJson(),
      };
}

/// Service admin contact, payment steps, and paid plan prices, set from the platform panel.
class RenewalInfo {
  const RenewalInfo({this.contact, this.paymentInstructions, this.plans = const []});

  factory RenewalInfo.fromJson(Map<String, dynamic> json) => RenewalInfo(
        contact: json['contact'] as String?,
        paymentInstructions: json['payment_instructions'] as String?,
        plans: [
          for (final plan in json['plans'] as List? ?? const [])
            if (plan is Map<String, dynamic>) RenewalPlan.fromJson(plan),
        ],
      );

  final String? contact;
  final String? paymentInstructions;
  final List<RenewalPlan> plans;

  bool get isEmpty => (contact ?? '').isEmpty && (paymentInstructions ?? '').isEmpty && plans.isEmpty;

  Map<String, dynamic> toJson() => {
        'contact': contact,
        'payment_instructions': paymentInstructions,
        'plans': [for (final plan in plans) plan.toJson()],
      };
}

class RenewalPlan {
  const RenewalPlan({required this.key, required this.label, required this.price});

  factory RenewalPlan.fromJson(Map<String, dynamic> json) => RenewalPlan(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String label;
  final int price;

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'price': price};
}
