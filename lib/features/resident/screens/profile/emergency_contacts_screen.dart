import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/emergency_contact_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../data/emergency_contact_repository.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _repository = EmergencyContactRepository();

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
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Text(
              "Texted alongside Tanod/police every time you trigger SOS — online or offline.",
              style: AppTypography.bodySoft(fontSize: 11),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyContactModel>>(
              stream: _repository.streamForResident(widget.user.uid),
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (contacts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppCard(child: const Text('No emergency contacts added yet.')),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final contact in contacts)
                      AppCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.tealLight,
                              child: Text(
                                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                style: AppTypography.display(fontSize: 12, color: AppColors.teal),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${contact.name} (${contact.relationship})', style: AppTypography.body(fontSize: 12.5)),
                                  Text(contact.phone, style: AppTypography.mono(fontSize: 10.5)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.urgent),
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(label: '＋ Add contact', variant: AppButtonVariant.outline, onPressed: _showAddDialog),
          ),
        ],
      ),
    );
  }
}
