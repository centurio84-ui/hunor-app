class ExconCategorySummary {
  final String categoryCode;
  final int evaluationCount;
  final int maxPossibleScore;
  final int totalAchievedScore;
  final double performancePercentage;

  const ExconCategorySummary({
    required this.categoryCode,
    required this.evaluationCount,
    required this.maxPossibleScore,
    required this.totalAchievedScore,
    required this.performancePercentage,
  });

  factory ExconCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExconCategorySummary(
      categoryCode: json['category_code'] as String? ?? 'N/A',
      evaluationCount: (json['evaluation_count'] as num?)?.toInt() ?? 0,
      maxPossibleScore: (json['max_possible_score'] as num?)?.toInt() ?? 0,
      totalAchievedScore: (json['total_achieved_score'] as num?)?.toInt() ?? 0,
      performancePercentage: (json['performance_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_code': categoryCode,
      'evaluation_count': evaluationCount,
      'max_possible_score': maxPossibleScore,
      'total_achieved_score': totalAchievedScore,
      'performance_percentage': performancePercentage,
    };
  }

  /// Emberileg jól olvasható kategórianév
  String get displayName {
    switch (categoryCode.toUpperCase()) {
      case 'OP-K9':
        return 'K9 Keresőkutya';
      case 'III/C':
      case 'CUT':
        return 'Vágás / Feltárás';
      case 'BREAK':
      case 'BRK':
        return 'Törés / Bontás';
      case 'ALP':
      case 'ALPIN':
        return 'Alpin / Kötél';
      case 'SHOR':
      case 'SHORING':
        return 'Shoring / Dúcolás';
      case 'MED':
        return 'Egészségügyi';
      case 'LOG':
        return 'Logisztika';
      default:
        return categoryCode;
    }
  }
}
