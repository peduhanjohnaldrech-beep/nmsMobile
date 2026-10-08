class UserModel {
  final int          id;
  final String       username;
  final String       fullName;
  final String       role;
  final String?      barangay;
  final List<String> permissions;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.barangay,
    this.permissions = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:          int.tryParse(json['id'].toString()) ?? 0,
      username:    json['username'] ?? '',
      fullName:    json['full_name'] ?? json['fullName'] ?? '',
      role:        (json['role'] ?? '').toString().toLowerCase(),
      barangay:    json['barangay'],
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':          id,
    'username':    username,
    'full_name':   fullName,
    'role':        role,
    'barangay':    barangay,
    'permissions': permissions,
  };

  // Modules a midwife is allowed — enforced regardless of stored permissions
  static const _midwifeAllowed = {'validation', 'beneficiaries'};

  bool hasPermission(String module) {
    if (isAdmin || isNutritionist) return true;
    if (isMidwife) return _midwifeAllowed.contains(module);
    return permissions.contains(module);
  }

  bool get isAdmin        => role == 'admin';
  bool get isNutritionist => role == 'nutritionist';
  bool get isEncoder      => role == 'encoder';
  bool get isBhw          => role == 'bhw';
  bool get isMidwife      => role == 'midwife';
  bool get isBns          => role == 'bns';

  bool get canDelete          => isAdmin || isNutritionist;
  bool get canAddBeneficiary  => true;
  bool get isScopedToBarangay => isBhw || isBns || isMidwife;

  String get roleDisplay {
    switch (role) {
      case 'admin':        return 'Administrator';
      case 'nutritionist': return 'Nutritionist';
      case 'encoder':      return 'Data Encoder';
      case 'bhw':          return 'Barangay Health Worker';
      case 'midwife':      return 'Midwife';
      case 'bns':          return 'Barangay Nutrition Scholar';
      default:             return role.isNotEmpty
          ? role[0].toUpperCase() + role.substring(1)
          : 'User';
    }
  }
}
