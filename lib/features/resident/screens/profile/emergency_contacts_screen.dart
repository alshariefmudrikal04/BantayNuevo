import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../models/emergency_contact_model.dart';
import '../../../../core/theme/lux_theme.dart';
import '../../data/emergency_contact_repository.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _repository = EmergencyContactRepository();
  late final Stream<List<EmergencyContactModel>> _contactsStream =
      _repository.streamForResident(widget.user.uid);

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add emergency contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: relationshipController, decoration: const InputDecoration(labelText: 'Relationship')),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) return;
              await _repository.addContact(
                residentId: widget.user.uid,
                name: nameController.text.trim(),
                relationship: relationshipController.text.trim(),
                phone: phoneController.text.trim(),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('EMERGENCY CONTACTS', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              "Texted alongside Tanod/police every time you trigger SOS — online or offline.",
              style: LuxType.body(fontSize: 11.5, color: LuxColors.inkSoft),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyContactModel>>(
              stream: _contactsStream,
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (contacts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                      child: Text('No emergency contacts added yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final contact in contacts)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: LuxColors.red,
                              child: Text(
                                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                style: LuxType.hero(fontSize: 13, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${contact.name} (${contact.relationship})', style: LuxType.heading(fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(contact.phone, style: LuxType.eyebrow(fontSize: 10, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: LuxColors.red),
                              onPressed: () => _repository.deleteContact(contact.id),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: LuxColors.red,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showAddDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text('＋ ADD CONTACT', style: LuxType.eyebrow(fontSize: 11.5, color: Colors.white, letterSpacing: 0.6)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
