import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerPayoutInformationScreen extends StatefulWidget {
  const OwnerPayoutInformationScreen({super.key});

  @override
  State<OwnerPayoutInformationScreen> createState() =>
      _OwnerPayoutInformationScreenState();
}

class _OwnerPayoutInformationScreenState
    extends State<OwnerPayoutInformationScreen> {
  late Future<AppUser?> _ownerFuture;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
  }

  Future<AppUser?> _loadOwner() async {
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser == null || authUser.role != AppUserRole.owner) {
      throw StateError('A signed-in bus owner is required.');
    }

    try {
      final owner = await context
          .read<UserRepository>()
          .getUserByUid(authUser.uid)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw TimeoutException('Loading the owner profile timed out.'),
          );

      if (owner == null || owner.role != AppUserRole.owner) {
        throw StateError('The authenticated owner profile was not found.');
      }

      return owner;
    } catch (error, stackTrace) {
      debugPrint('[OWNER PAYOUT] Failed to load owner profile: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to earnings',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Payout Information'),
      ),
      body: SafeArea(
        child: FutureBuilder<AppUser?>(
          future: _ownerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: BusGoLoadingState(
                  label: 'Loading your payout information...',
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: BusGoErrorState(
                  title: "Couldn't load payout information",
                  message:
                      'Please check your connection and try again. Your account details have not been changed.',
                  onRetry: () => setState(() => _ownerFuture = _loadOwner()),
                ),
              );
            }

            final owner = snapshot.data;
            if (owner == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: BusGoErrorState(
                  title: 'Owner profile unavailable',
                  message:
                      'The authenticated owner profile could not be loaded.',
                  onRetry: () => setState(() => _ownerFuture = _loadOwner()),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Payout Information',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Payout details for your BUSGO owner account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                BusGoSurface(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No payout information added yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'There are no payout or bank details stored for ${owner.name.trim().isEmpty ? 'this owner account' : owner.name.trim()}.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
