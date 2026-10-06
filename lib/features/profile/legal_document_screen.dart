import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/app_roles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_ui.dart';

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
    this.about = false,
  });

  final String title;
  final List<LegalSection> sections;
  final bool about;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.about) return _aboutBusGo(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: ${widget.title}');
            debugPrint('previousScreen: legal documents');
            debugPrint('navigationType: ${context.canPop() ? 'pop' : 'no-op'}');
            debugPrint('canPop: ${context.canPop()}');
            debugPrint('[/BUSGO BACK NAVIGATION]');
            if (context.canPop()) {
              context.pop();
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 18),
              for (final section in widget.sections) ...[
                const SizedBox(height: 8),
                Text(
                  section.heading,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutBusGo(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final roleLabel = user?.role.label ?? 'BUSGO';
    final name = user?.name.trim() ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'B';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About BUSGO',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: About BUSGO');
            debugPrint('previousScreen: previous screen');
            debugPrint('navigationType: ${context.canPop() ? 'pop' : 'no-op'}');
            debugPrint('canPop: ${context.canPop()}');
            debugPrint('[/BUSGO BACK NAVIGATION]');
            if (context.canPop()) {
              context.pop();
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BusGoBrandMark(compact: true),
                        const SizedBox(height: 3),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BusGoProfileAvatar(
                    imageUrl: user?.profileImageUrl,
                    size: 42,
                    label: initials,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'About BUSGO',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'App information and details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              BusGoSurface(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const BusGoBrandMark(),
                    const SizedBox(height: 14),
                    Text(
                      'Bus Management Platform',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Connecting customers, bus owners and administrators',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _aboutInformation(context),
              const SizedBox(height: 14),
              BusGoSurface(
                child: Text(
                  'BUSGO is a bus management platform that connects customers, bus owners, and administrators through bus discovery, trip requests, approvals, bookings, and travel operations.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              _aboutLink(
                context,
                title: 'Terms of Service',
                subtitle: 'Read the BUSGO user agreement',
                icon: Icons.description_outlined,
                color: BusGoTokens.blue,
                onTap: () => context.push('/legal/terms'),
              ),
              _aboutLink(
                context,
                title: 'Privacy Policy',
                subtitle: 'Learn how BUSGO uses account information',
                icon: Icons.privacy_tip_outlined,
                color: const Color(0xFF159A68),
                onTap: () => context.push('/legal/privacy'),
              ),
              _aboutLink(
                context,
                title: 'Open Source Licenses',
                subtitle: 'View licenses for Flutter packages',
                icon: Icons.article_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () =>
                    showLicensePage(context: context, applicationName: 'BUSGO'),
              ),
              _aboutLink(
                context,
                title: 'Help & Support',
                subtitle: 'Read answers about accounts and trips',
                icon: Icons.support_agent_rounded,
                color: const Color(0xFF159A68),
                onTap: () => context.push('/help'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutInformation(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _packageInfoFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const BusGoSurface(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const BusGoSurface(
          child: Text('App version information could not be loaded.'),
        );
      }
      final info = snapshot.data!;
      return BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _aboutDetail(
              context,
              'Version',
              info.version,
              Icons.tag_outlined,
              BusGoTokens.blue,
            ),
            _aboutDetail(
              context,
              'Build Number',
              info.buildNumber,
              Icons.build_circle_outlined,
              const Color(0xFF159A68),
            ),
          ],
        ),
      );
    },
  );

  Widget _aboutDetail(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _aboutLink(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BusGoSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}
