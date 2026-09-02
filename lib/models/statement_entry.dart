class StatementEntry {
  final int date;
  final String type;
  final String description;
  final double amount;
  final String? crop;
  final String? field;

  const StatementEntry({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    this.crop,
    this.field,
  });
}
