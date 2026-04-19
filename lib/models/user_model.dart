class User {
  final String id;
  final String email;
  final String fullName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      // Xử lý cả backend trả về PascalCase (Email, FullName) và camelCase (email, fullName)
      String id = json['_id'] ?? json['id'] ?? '';
      String email = json['email'] ?? json['Email'] ?? '';
      String fullName = json['fullName'] ?? json['FullName'] ?? '';
      
      DateTime createdAt = DateTime.now();
      if (json['createdAt'] != null) {
        createdAt = DateTime.parse(json['createdAt'].toString());
      } else if (json['CreatedAt'] != null) {
        createdAt = DateTime.parse(json['CreatedAt'].toString());
      }
      
      return User(
        id: id,
        email: email,
        fullName: fullName,
        createdAt: createdAt,
      );
    } catch (e) {
      print('Lỗi parse User: $e');
      return User(
        id: json['_id'] ?? json['id'] ?? '',
        email: json['email'] ?? json['Email'] ?? '',
        fullName: json['fullName'] ?? json['FullName'] ?? '',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'fullName': fullName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
