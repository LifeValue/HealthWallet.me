/// Data Transfer Object for API source response
class SourceDto {
  final String id;
  final String? platformName;
  final String? logo;
  final String? labelSource;
  final String? platformType;
  final String? createdAt;
  final String? updatedAt;
  final String? display;

  const SourceDto({
    required this.id,
    this.platformName,
    this.logo,
    this.labelSource,
    this.platformType,
    this.createdAt,
    this.updatedAt,
    this.display,
  });

  factory SourceDto.fromJson(Map<String, dynamic> json) {
    return SourceDto(
      id: json['id'] ?? '',
      platformName: json['name'] ?? json['display'] ?? json['platform_name'],
      logo: json['logo'],
      labelSource:
          json['display'] ??
          json['name'] ??
          json['labelSource'] ??
          json['label'],
      platformType:
          json['platform_type'] ??
          'fasten', // Default to fasten for API sources
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      display: json['display'] ?? json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform_name': platformName,
      'logo': logo,
      'labelSource': labelSource,
      'platform_type': platformType,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'display': display,
    };
  }
}
