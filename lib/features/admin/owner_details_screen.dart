import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../widgets/busgo_ui.dart';

class AdminOwnerDetailsScreen extends StatelessWidget {
  const AdminOwnerDetailsScreen({super.key, required this.owner});

  final AppUser owner;

  @override
  Widget build(BuildContext context) {
    final status = owner.approvalStatus ?? 'approved';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Details'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const BusGoBrandMark(compact: true),
            const SizedBox(height: 6),
            Text(
              'Travel Together, Go Further',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            BusGoSurface(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BusGoProfileAvatar(
                        imageUrl: owner.profileImageUrl,
                        size: 64,
                        label: owner.name.isEmpty
                            ? 'O'
                            : owner.name[0].toUpperCase(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              owner.name.isEmpty ? 'Unnamed owner' : owner.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bus Owner',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: BusGoTokens.blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  BusGoStatusChip(
                    label: status == 'pending'
                        ? 'PENDING REVIEW'
                        : status.toUpperCase(),
                    tone: status == 'pending'
                        ? BusGoStatusTone.warning
                        : status == 'approved'
                        ? BusGoStatusTone.positive
                        : BusGoStatusTone.negative,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BusGoSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  _infoRow(context, Icons.email_outlined, 'Email', owner.email),
                  _infoRow(
                    context,
                    Icons.phone_outlined,
                    'Phone',
                    owner.phone ?? 'Not provided',
                  ),
                  _infoRow(
                    context,
                    Icons.calendar_today_outlined,
                    'Registered',
                    owner.createdAt == null
                        ? 'Not provided'
                        : _date(owner.createdAt!),
                  ),
                  _infoRow(
                    context,
                    Icons.badge_outlined,
                    'Owner ID',
                    owner.uid,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: BusGoTokens.blue),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}
