class News {
  final String title;
  final String link;
  final String? imageUrl;
  final String date;
  final String? description;
  final String? source;
  final DateTime? pubDate;

  News({
    required this.title,
    required this.link,
    this.imageUrl,
    required this.date,
    this.description,
    this.source,
    this.pubDate,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      imageUrl: json['imageUrl'],
      date: json['date'] ?? '',
      description: json['description'],
      source: json['source'],
      pubDate: json['pubDate'] != null ? DateTime.tryParse(json['pubDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'link': link,
      'imageUrl': imageUrl,
      'date': date,
      'description': description,
      'source': source,
      'pubDate': pubDate?.toIso8601String(),
    };
  }
}
