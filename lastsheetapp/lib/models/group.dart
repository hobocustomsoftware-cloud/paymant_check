class Group {
  final int? id;
  final int owner; // owner ID
  final String? ownerUsername;
  final String groupTitle;
  final String groupType;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Group({
    this.id,
    required this.owner,
    this.ownerUsername,
    required this.groupTitle,
    required this.groupType,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      owner: json['owner'],
      ownerUsername: json['owner_username'],
      groupTitle: json['group_title'],
      groupType: json['group_type'],
      name: json['name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'group_title': groupTitle,
      'group_type': groupType,
      'name': name,
    };
  }
}