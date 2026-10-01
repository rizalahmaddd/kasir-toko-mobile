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
      };
}
