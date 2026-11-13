class Idea {
  final String id;
  final String title;
  final String description;
  final String userId;

  const Idea({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
  });

  factory Idea.fromFirebase(String id, Map<String, dynamic> data) {
    return Idea(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'title': title,
      'description': description,
      'userId': userId,
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'userId': userId,
    };
  }

  factory Idea.fromCacheMap(Map<String, dynamic> data) {
    return Idea(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
    );
  }
}
