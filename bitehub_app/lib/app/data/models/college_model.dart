String _normalizeCollegeName(String name) {
  return name.trim();
}

String? _normalizeCafeImage(dynamic value) {
  final image = value?.toString().trim() ?? '';
  return image.isEmpty ? null : image;
}

bool _parseBool(dynamic value, {bool defaultValue = true}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return defaultValue;
}

class CollegeModel {
  final String id;
  final String name;
  final String? image;
  final bool isActive;
  final bool isAcceptingOrders;

  CollegeModel({
    required this.id,
    required this.name,
    this.image,
    this.isActive = true,
    this.isAcceptingOrders = true,
  });

  bool get canAcceptOrders => isActive && isAcceptingOrders;

  factory CollegeModel.fromJson(Map<String, dynamic> json) {
    return CollegeModel(
      id: json['id']?.toString() ?? '0',
      name: _normalizeCollegeName(
        (json['name'] ?? json['college_name'] ?? 'كلية غير معروفة').toString(),
      ),
      image: _normalizeCafeImage(
        json['image'] ?? json['logo'] ?? json['icon_url'],
      ),
      isActive: _parseBool(json['is_active']),
      isAcceptingOrders: _parseBool(json['is_accepting_orders']),
    );
  }

  factory CollegeModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CollegeModel(
      id: id,
      name: _normalizeCollegeName(
        (data['name'] ?? data['college_name'] ?? '').toString(),
      ),
      image: _normalizeCafeImage(data['image'] ?? data['logo']),
      isActive: _parseBool(data['is_active']),
      isAcceptingOrders: _parseBool(data['is_accepting_orders']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollegeModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
