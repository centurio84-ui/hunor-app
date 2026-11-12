class ParticipantEvaluation {
  final String? id;
  final DateTime? createdAt;
  final String formType; // 'T0' vagy 'T1'
  final String anonToken;
  final Map<String, dynamic> responses;

  const ParticipantEvaluation({
    this.id,
    this.createdAt,
    required this.formType,
    required this.anonToken,
    required this.responses,
  }) : assert(formType == 'T0' || formType == 'T1', 'formType értéke csak T0 vagy T1 lehet');

  factory ParticipantEvaluation.fromJson(Map<String, dynamic> json) {
    return ParticipantEvaluation(
      id: json['id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      formType: json['form_type'] as String? ?? 'T0',
      anonToken: json['anon_token'] as String? ?? '',
      responses: json['responses'] != null
          ? Map<String, dynamic>.from(json['responses'] as Map)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'form_type': formType,
      'anon_token': anonToken.trim().toUpperCase(),
      'responses': responses,
    };
  }
}
