class CropPrice {
  final String name;
  final String minPrice;
  final String maxPrice;
  final String date;
  final String gujaratiName;
  final String yardName;
  final String variety;
  final String income;

  CropPrice({
    required this.name,
    required this.minPrice,
    required this.maxPrice,
    required this.date,
    this.gujaratiName = '',
    this.yardName = '',
    this.variety = '',
    this.income = '',
  });

  factory CropPrice.fromJson(Map<String, dynamic> json) {
    return CropPrice(
      name: json['name'] ?? '',
      minPrice: json['minPrice'] ?? '',
      maxPrice: json['maxPrice'] ?? '',
      date: json['date'] ?? '',
      gujaratiName: json['gujaratiName'] ?? '',
      yardName: json['yardName'] ?? '',
      variety: json['variety'] ?? '',
      income: json['income'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'date': date,
      'gujaratiName': gujaratiName,
      'yardName': yardName,
      'variety': variety,
      'income': income,
    };
  }

  factory CropPrice.empty() {
    return CropPrice(name: '', minPrice: '', maxPrice: '', date: '', variety: '', income: '');
  }
}
