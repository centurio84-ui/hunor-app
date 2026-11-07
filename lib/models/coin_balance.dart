/// Mentési érme és elismerési egyenleg (Rescue Coin / RC) modell.

class CoinBalance {
  final String organizationId;
  final String membershipId;
  final String unit; // 'RC'
  final int balance;
  final DateTime asOf;
  final String ledgerVersion;

  const CoinBalance({
    required this.organizationId,
    required this.membershipId,
    required this.unit,
    required this.balance,
    required this.asOf,
    required this.ledgerVersion,
  });

  factory CoinBalance.fromJson(Map<String, dynamic> json) {
    return CoinBalance(
      organizationId: json['organization_id']?.toString() ?? '',
      membershipId: json['membership_id']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'RC',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      asOf: DateTime.tryParse(json['as_of']?.toString() ?? '') ?? DateTime.now(),
      ledgerVersion: json['ledger_version']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'organization_id': organizationId,
    'membership_id': membershipId,
    'unit': unit,
    'balance': balance,
    'as_of': asOf.toIso8601String(),
    'ledger_version': ledgerVersion,
  };
}
