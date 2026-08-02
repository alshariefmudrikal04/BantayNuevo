class EmergencyContactModel {
  const EmergencyContactModel({
    required this.id,
    required this.residentId,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String id;
  final String residentId;
  final String name;
  final String relationship;
  final String phone;

  factory EmergencyContactModel.fromFirestore(Map<String, dynamic> data, String id) => EmergencyContactModel(
        id: id,
        residentId: data['residentId'] as String? ?? '',
        name: data['name'] as String? ?? '',
        relationship: data['relationship'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'residentId': residentId,
        'name': name,
        'relationship': relationship,
        'phone': phone,
      };
}
