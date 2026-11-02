enum MemberReportReason {
  harassment,
  inappropriateContent,
  nonconsensualLocation,
  impersonation,
  spamOrFraud,
  other,
}

extension MemberReportReasonDetails on MemberReportReason {
  String get apiValue => switch (this) {
    MemberReportReason.harassment => 'HARASSMENT',
    MemberReportReason.inappropriateContent => 'INAPPROPRIATE_CONTENT',
    MemberReportReason.nonconsensualLocation => 'NONCONSENSUAL_LOCATION',
    MemberReportReason.impersonation => 'IMPERSONATION',
    MemberReportReason.spamOrFraud => 'SPAM_OR_FRAUD',
    MemberReportReason.other => 'OTHER',
  };

  String get label => switch (this) {
    MemberReportReason.harassment => 'Acoso o intimidación',
    MemberReportReason.inappropriateContent => 'Contenido inapropiado',
    MemberReportReason.nonconsensualLocation =>
      'Compartir ubicación sin permiso',
    MemberReportReason.impersonation => 'Suplantación de identidad',
    MemberReportReason.spamOrFraud => 'Spam o fraude',
    MemberReportReason.other => 'Otro motivo',
  };
}

class MemberReportRequest {
  final MemberReportReason reason;
  final String? details;

  const MemberReportRequest({required this.reason, this.details});

  Map<String, dynamic> toJson() {
    return {
      'reason': reason.apiValue,
      if (details != null && details!.trim().isNotEmpty)
        'details': details!.trim(),
    };
  }
}
