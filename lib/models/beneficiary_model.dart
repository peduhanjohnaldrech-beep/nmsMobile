class BeneficiaryModel {
  final int     id;
  final String  lastName;
  final String  firstName;
  final String? middleName;
  final String? suffix;
  final String  dateOfBirth;
  final String  sex;
  final String? placeOfBirth;
  final String  barangay;
  final String? purokZone;
  final String? householdNo;
  final String? motherName;
  final String? fatherName;
  final String? guardianName;
  final String? guardianRelationship;
  final String? contactNumber;
  final String? philhealthStatus;
  final int     is4psMember;
  final String? nhtsStatus;
  final String? incomeClassification;
  final double? householdMonthlyIncome;
  final String? incomeSource;
  final int     isPwdHousehold;
  final int     isIndigenousPeople;
  final String? ipGroup;
  final String? source;
  final String? createdAt;
  final String? updatedAt;

  // Offline — local UUID before server assigns real ID
  final String? localId;

  // Validation workflow
  final String? validationStatus;
  final String? submittedAt;

  // Latest assessment info (joined from assessments table)
  final String? latestStatus;
  final String? latestAssessmentDate;
  final double? latestWeightKg;
  final double? latestZscore;

  BeneficiaryModel({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName,
    this.suffix,
    required this.dateOfBirth,
    required this.sex,
    this.placeOfBirth,
    required this.barangay,
    this.purokZone,
    this.householdNo,
    this.motherName,
    this.fatherName,
    this.guardianName,
    this.guardianRelationship,
    this.contactNumber,
    this.philhealthStatus,
    this.is4psMember = 0,
    this.nhtsStatus,
    this.incomeClassification,
    this.householdMonthlyIncome,
    this.incomeSource,
    this.isPwdHousehold = 0,
    this.isIndigenousPeople = 0,
    this.ipGroup,
    this.source,
    this.createdAt,
    this.updatedAt,
    this.localId,
    this.validationStatus,
    this.submittedAt,
    this.latestStatus,
    this.latestAssessmentDate,
    this.latestWeightKg,
    this.latestZscore,
  });

  /// e.g. "Dela Cruz, Juan M."
  String get displayName {
    final mi = middleName != null && middleName!.isNotEmpty
        ? ' ${middleName![0].toUpperCase()}.'
        : '';
    final sfx = suffix != null && suffix!.isNotEmpty ? ' $suffix' : '';
    return '$lastName, $firstName$mi$sfx';
  }

  /// Full name for display in forms
  String get fullName => '$firstName${middleName != null ? ' $middleName' : ''} $lastName';

  /// Initials for avatar
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty  ? lastName[0].toUpperCase()  : '';
    return '$f$l';
  }

  /// Age in years computed from dateOfBirth
  int get ageInYears {
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  /// Age in months
  int get ageInMonths {
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return 0;
    final now = DateTime.now();
    return (now.year - dob.year) * 12 + (now.month - dob.month);
  }

  bool get isPendingValidation => validationStatus == 'pending';
  bool get isRejected          => validationStatus == 'rejected';
  bool get isValidated         => validationStatus == 'validated';
  bool get isSubmitted         => submittedAt != null && submittedAt!.isNotEmpty;

  bool get is4ps            => is4psMember == 1;
  bool get isPwd            => isPwdHousehold == 1;
  bool get isIP             => isIndigenousPeople == 1;

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    return BeneficiaryModel(
      id:               int.tryParse(json['id'].toString()) ?? 0,
      lastName:         json['last_name']  ?? '',
      firstName:        json['first_name'] ?? '',
      middleName:       json['middle_name'],
      suffix:           json['suffix'],
      dateOfBirth:      json['date_of_birth'] ?? '',
      sex:              json['sex'] ?? '',
      placeOfBirth:     json['place_of_birth'],
      barangay:         json['barangay'] ?? '',
      purokZone:        json['purok_zone'],
      householdNo:      json['household_no'],
      motherName:       json['mother_name'],
      fatherName:       json['father_name'],
      guardianName:     json['guardian_name'],
      guardianRelationship: json['guardian_relationship'],
      contactNumber:    json['contact_number'],
      philhealthStatus: json['philhealth_status'],
      is4psMember:      int.tryParse(json['is_4ps_member']?.toString() ?? '0') ?? 0,
      nhtsStatus:       json['nhts_pr_status'],
      incomeClassification:     json['income_classification'],
      householdMonthlyIncome:   json['household_monthly_income'] != null
          ? double.tryParse(json['household_monthly_income'].toString())
          : null,
      incomeSource:     json['income_source'],
      isPwdHousehold:   int.tryParse(json['is_pwd_household']?.toString() ?? '0') ?? 0,
      isIndigenousPeople: int.tryParse(json['is_indigenous_people']?.toString() ?? '0') ?? 0,
      ipGroup:          json['ip_group'],
      source:           json['source'],
      createdAt:        json['created_at'],
      updatedAt:        json['updated_at'],
      localId:          json['local_id'],
      validationStatus: json['validation_status'],
      submittedAt:      json['submitted_at'],
      latestStatus:     json['latest_status'],
      latestAssessmentDate: json['latest_assessment_date'],
      latestWeightKg:   json['latest_weight_kg'] != null
          ? double.tryParse(json['latest_weight_kg'].toString())
          : null,
      latestZscore:     json['latest_zscore'] != null
          ? double.tryParse(json['latest_zscore'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'last_name':              lastName,
    'first_name':             firstName,
    'middle_name':            middleName,
    'suffix':                 suffix,
    'date_of_birth':          dateOfBirth,
    'sex':                    sex,
    'place_of_birth':         placeOfBirth,
    'barangay':               barangay,
    'purok_zone':             purokZone,
    'household_no':           householdNo,
    'mother_name':            motherName,
    'father_name':            fatherName,
    'guardian_name':          guardianName,
    'guardian_relationship':  guardianRelationship,
    'contact_number':         contactNumber,
    'philhealth_status':      philhealthStatus,
    'is_4ps_member':          is4psMember,
    'nhts_pr_status':         nhtsStatus,
    'income_classification':  incomeClassification,
    'household_monthly_income': householdMonthlyIncome,
    'income_source':          incomeSource,
    'is_pwd_household':       isPwdHousehold,
    'is_indigenous_people':   isIndigenousPeople,
    'ip_group':               ipGroup,
    'source':                 source ?? 'Mobile',
    if (localId != null) 'local_id': localId,
  };

  BeneficiaryModel copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? middleName,
    String? suffix,
    String? dateOfBirth,
    String? sex,
    String? placeOfBirth,
    String? barangay,
    String? purokZone,
    String? householdNo,
    String? motherName,
    String? fatherName,
    String? guardianName,
    String? guardianRelationship,
    String? contactNumber,
    String? philhealthStatus,
    int? is4psMember,
    String? nhtsStatus,
    String? incomeClassification,
    double? householdMonthlyIncome,
    String? incomeSource,
    int? isPwdHousehold,
    int? isIndigenousPeople,
    String? ipGroup,
    String? source,
    String? createdAt,
    String? updatedAt,
    String? localId,
    String? validationStatus,
    String? submittedAt,
    String? latestStatus,
    String? latestAssessmentDate,
    double? latestWeightKg,
    double? latestZscore,
  }) {
    return BeneficiaryModel(
      id:               id ?? this.id,
      lastName:         lastName ?? this.lastName,
      firstName:        firstName ?? this.firstName,
      middleName:       middleName ?? this.middleName,
      suffix:           suffix ?? this.suffix,
      dateOfBirth:      dateOfBirth ?? this.dateOfBirth,
      sex:              sex ?? this.sex,
      placeOfBirth:     placeOfBirth ?? this.placeOfBirth,
      barangay:         barangay ?? this.barangay,
      purokZone:        purokZone ?? this.purokZone,
      householdNo:      householdNo ?? this.householdNo,
      motherName:       motherName ?? this.motherName,
      fatherName:       fatherName ?? this.fatherName,
      guardianName:     guardianName ?? this.guardianName,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
      contactNumber:    contactNumber ?? this.contactNumber,
      philhealthStatus: philhealthStatus ?? this.philhealthStatus,
      is4psMember:      is4psMember ?? this.is4psMember,
      nhtsStatus:       nhtsStatus ?? this.nhtsStatus,
      incomeClassification:   incomeClassification ?? this.incomeClassification,
      householdMonthlyIncome: householdMonthlyIncome ?? this.householdMonthlyIncome,
      incomeSource:     incomeSource ?? this.incomeSource,
      isPwdHousehold:   isPwdHousehold ?? this.isPwdHousehold,
      isIndigenousPeople: isIndigenousPeople ?? this.isIndigenousPeople,
      ipGroup:          ipGroup ?? this.ipGroup,
      source:           source ?? this.source,
      createdAt:        createdAt ?? this.createdAt,
      updatedAt:        updatedAt ?? this.updatedAt,
      localId:          localId ?? this.localId,
      validationStatus: validationStatus ?? this.validationStatus,
      submittedAt:      submittedAt ?? this.submittedAt,
      latestStatus:     latestStatus ?? this.latestStatus,
      latestAssessmentDate: latestAssessmentDate ?? this.latestAssessmentDate,
      latestWeightKg:   latestWeightKg ?? this.latestWeightKg,
      latestZscore:     latestZscore ?? this.latestZscore,
    );
  }
}
