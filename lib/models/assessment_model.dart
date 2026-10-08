import 'package:flutter/material.dart';

class AssessmentModel {
  final int     id;
  final int     beneficiaryId;
  final String  assessmentDate;
  final int     ageInMonths;
  final double  weightKg;
  final double? heightCm;
  final double? muacCm;
  final String  nutritionalStatus;
  final double? weightForAgeZscore;
  final double? heightForAgeZscore;
  final String? hfaStatus;
  final double? wflhZscore;
  final String? wflhStatus;
  final String? validationStatus;
  final String  period;
  final int     assessmentYear;
  final String? assessedBy;
  final String? remarks;
  final String? createdAt;

  // From JOIN with beneficiaries table
  final String? lastName;
  final String? firstName;
  final String? barangay;

  // Offline tracking
  final String? localId;
  final String? localBeneficiaryId;

  AssessmentModel({
    required this.id,
    required this.beneficiaryId,
    required this.assessmentDate,
    required this.ageInMonths,
    required this.weightKg,
    this.heightCm,
    this.muacCm,
    required this.nutritionalStatus,
    this.weightForAgeZscore,
    this.heightForAgeZscore,
    this.hfaStatus,
    this.wflhZscore,
    this.wflhStatus,
    this.validationStatus,
    required this.period,
    required this.assessmentYear,
    this.assessedBy,
    this.remarks,
    this.createdAt,
    this.lastName,
    this.firstName,
    this.barangay,
    this.localId,
    this.localBeneficiaryId,
  });

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    return AssessmentModel(
      id:                 int.tryParse(json['id'].toString()) ?? 0,
      beneficiaryId:      int.tryParse(json['beneficiary_id'].toString()) ?? 0,
      assessmentDate:     json['assessment_date'] ?? '',
      ageInMonths:        int.tryParse(json['age_in_months'].toString()) ?? 0,
      weightKg:           double.tryParse(json['weight_kg'].toString()) ?? 0,
      heightCm:           json['height_cm'] != null ? double.tryParse(json['height_cm'].toString()) : null,
      muacCm:             json['muac_cm']   != null ? double.tryParse(json['muac_cm'].toString())   : null,
      nutritionalStatus:  json['nutritional_status'] ?? 'Normal',
      weightForAgeZscore: json['weight_for_age_zscore'] != null
          ? double.tryParse(json['weight_for_age_zscore'].toString())
          : null,
      heightForAgeZscore: json['height_for_age_zscore'] != null
          ? double.tryParse(json['height_for_age_zscore'].toString())
          : null,
      hfaStatus:          json['hfa_status'],
      wflhZscore:         json['wflh_zscore'] != null
          ? double.tryParse(json['wflh_zscore'].toString())
          : null,
      wflhStatus:         json['wflh_status'],
      validationStatus:   json['validation_status'],
      period:             json['period'] ?? 'January',
      assessmentYear:     int.tryParse(json['assessment_year'].toString()) ?? DateTime.now().year,
      assessedBy:         json['assessed_by'],
      remarks:            json['remarks'],
      createdAt:          json['created_at'],
      lastName:           json['last_name'],
      firstName:          json['first_name'],
      barangay:           json['barangay'],
      localId:            json['local_id'],
      localBeneficiaryId: json['local_beneficiary_id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'beneficiary_id':  beneficiaryId,
    'assessment_date': assessmentDate,
    'weight_kg':       weightKg,
    if (heightCm != null) 'height_cm': heightCm,
    if (muacCm != null)   'muac_cm':   muacCm,
    'period':          period,
    'assessment_year': assessmentYear,
    if (assessedBy != null) 'assessed_by': assessedBy,
    if (remarks != null)    'remarks':     remarks,
    if (localId != null)             'local_id':             localId,
    if (localBeneficiaryId != null)  'local_beneficiary_id': localBeneficiaryId,
  };

  // -------------------------------------------------------
  // Display helpers
  // -------------------------------------------------------

  String get beneficiaryName {
    if (firstName != null && lastName != null) return '$lastName, $firstName';
    return 'Beneficiary #$beneficiaryId';
  }

  String get ageDisplay {
    if (ageInMonths < 12) return '$ageInMonths mo';
    final y = ageInMonths ~/ 12;
    final m = ageInMonths % 12;
    return m > 0 ? '${y}y ${m}mo' : '${y}y';
  }

  String get statusLabel {
    switch (nutritionalStatus) {
      case 'SUW': return 'Severely Underweight';
      case 'UW':  return 'Underweight';
      case 'OW':  return 'Overweight';
      case 'OB':  return 'Obese';
      default:    return 'Normal';
    }
  }

  Color get statusColor {
    switch (nutritionalStatus) {
      case 'SUW': return const Color(0xFFD32F2F);
      case 'UW':  return const Color(0xFFF57C00);
      case 'OW':  return const Color(0xFFF9A825);
      case 'OB':  return const Color(0xFF7B1FA2);
      default:    return const Color(0xFF2E7D32);
    }
  }

  bool get isPending => validationStatus == 'pending';

  String get zscoreDisplay {
    if (weightForAgeZscore == null) return '—';
    return weightForAgeZscore!.toStringAsFixed(2);
  }

  String get hfaZscoreDisplay {
    if (heightForAgeZscore == null) return '—';
    return heightForAgeZscore!.toStringAsFixed(2);
  }

  String get wflhZscoreDisplay {
    if (wflhZscore == null) return '—';
    return wflhZscore!.toStringAsFixed(2);
  }

  String get periodDisplay => '$period $assessmentYear';

  /// '1st Period' for January, '2nd Period' for July
  String get periodLabel => period == 'July' ? '2nd Period' : '1st Period';

  int get periodNumber => period == 'July' ? 2 : 1;
}

/// Utility function for status color — also used by widgets
Color nutritionStatusColor(String status) {
  switch (status) {
    case 'SUW': return const Color(0xFFD32F2F);
    case 'UW':  return const Color(0xFFF57C00);
    case 'OW':  return const Color(0xFFF9A825);
    case 'OB':  return const Color(0xFF7B1FA2);
    default:    return const Color(0xFF2E7D32);
  }
}

String nutritionStatusLabel(String status) {
  switch (status) {
    case 'SUW': return 'Severely Underweight';
    case 'UW':  return 'Underweight';
    case 'OW':  return 'Overweight';
    case 'OB':  return 'Obese';
    default:    return 'Normal';
  }
}
