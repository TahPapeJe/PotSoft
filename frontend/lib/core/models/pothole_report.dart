class PotholeReport {
  final String id;
  final double userLat;
  final double userLong;
  final String imageFile;
  final DateTime timestamp;
  final bool isPothole;
  final String sizeCategory;
  final String priorityColor;
  final String jurisdiction;
  final String estimatedDuration;
  final String status;

  PotholeReport({
    required this.id,
    required this.userLat,
    required this.userLong,
    required this.imageFile,
    required this.timestamp,
    required this.isPothole,
    required this.sizeCategory,
    required this.priorityColor,
    required this.jurisdiction,
    required this.estimatedDuration,
    required this.status,
  }) : assert(
         ['Reported', 'Analyzed', 'In Progress', 'Finished'].contains(status),
         'Status must be one of: Reported, Analyzed, In Progress, Finished',
       );

  PotholeReport copyWith({
    String? id,
    double? userLat,
    double? userLong,
    String? imageFile,
    DateTime? timestamp,
    bool? isPothole,
    String? sizeCategory,
    String? priorityColor,
    String? jurisdiction,
    String? estimatedDuration,
    String? status,
  }) {
    return PotholeReport(
      id: id ?? this.id,
      userLat: userLat ?? this.userLat,
      userLong: userLong ?? this.userLong,
      imageFile: imageFile ?? this.imageFile,
      timestamp: timestamp ?? this.timestamp,
      isPothole: isPothole ?? this.isPothole,
      sizeCategory: sizeCategory ?? this.sizeCategory,
      priorityColor: priorityColor ?? this.priorityColor,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      status: status ?? this.status,
    );
  }

  factory PotholeReport.fromJson(Map<String, dynamic> json) {
    return PotholeReport(
      id: json['id'] as String,
      userLat: (json['user_lat'] as num).toDouble(),
      userLong: (json['user_long'] as num).toDouble(),
      imageFile: json['image_file'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isPothole: json['is_pothole'] as bool,
      sizeCategory: json['size_category'] as String,
      priorityColor: json['priority_color'] as String,
      jurisdiction: json['jurisdiction'] as String,
      estimatedDuration: json['estimated_duration'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_lat': userLat,
      'user_long': userLong,
      'image_file': imageFile,
      'timestamp': timestamp.toIso8601String(),
      'is_pothole': isPothole,
      'size_category': sizeCategory,
      'priority_color': priorityColor,
      'jurisdiction': jurisdiction,
      'estimated_duration': estimatedDuration,
      'status': status,
    };
  }
}
