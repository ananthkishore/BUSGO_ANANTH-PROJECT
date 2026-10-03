import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../providers/auth_provider.dart' as busgo_auth;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _splashAssetPath = 'assets/images/busgo_splash.png';

  late final busgo_auth.AuthProvider _authProvider;
  Timer? _startupTimer;
  bool _hasRouted = false;
  bool _startupDelayComplete = false;
  bool _hasLoggedResponsiveLayout = false;

  void _logSplashMetrics(BoxConstraints constraints) {
    if (_hasLoggedResponsiveLayout) return;

    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;
    final screenAspectRatio = availableWidth / availableHeight;
    final imageProvider = const AssetImage(_splashAssetPath);
    final imageConfiguration = createLocalImageConfiguration(
      context,
      size: Size(availableWidth, availableHeight),
    );

    _hasLoggedResponsiveLayout = true;
    imageProvider
        .resolve(imageConfiguration)
        .addListener(
          ImageStreamListener((imageInfo, _) {
            final imageWidth = imageInfo.image.width.toDouble();
            final imageHeight = imageInfo.image.height.toDouble();
            final imageAspectRatio = imageWidth / imageHeight;

            debugPrint('''
[BUSGO SPLASH DEBUG]
availableWidth: $availableWidth
availableHeight: $availableHeight
aspectRatio: $screenAspectRatio
imageAspectRatio: $imageAspectRatio
[/BUSGO SPLASH DEBUG]''');
          }),
        );
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[BUSGO STARTUP] App started');
    _authProvider = context.read<busgo_auth.AuthProvider>();
    _authProvider.addListener(_routeIfReady);
    _startupTimer = Timer(const Duration(milliseconds: 2500), () {
      debugPrint('[BUSGO STARTUP] Splash delay complete');
      _startupDelayComplete = true;
      _routeIfReady();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[BUSGO STARTUP] Showing BUSGO splash');
      _routeIfReady();
    });
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _authProvider.removeListener(_routeIfReady);
    super.dispose();
  }

  void _routeIfReady() {
    if (!mounted || _hasRouted) return;
    if (!_startupDelayComplete) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final user = _authProvider.currentUser;

    if (_authProvider.isLoading && user == null) {
      debugPrint(
        '[BUSGO STARTUP] Waiting for profile load for UID=${firebaseUser?.uid ?? 'unknown'}',
      );
      return;
    }

    final errorMessage = _authProvider.errorMessage;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      debugPrint('[BUSGO STARTUP] Splash profile error: $errorMessage');
      _hasRouted = true;
      context.go('/login');
      return;
    }

    final resolvedUser = user;
    if (resolvedUser == null) {
      _hasRouted = true;
      debugPrint('[BUSGO STARTUP] Firebase user: none -> navigating to Login');
      context.go('/login');
      return;
    }

    debugPrint(
      '[BUSGO STARTUP] Authenticated: true -> role=${resolvedUser.role.name}',
    );
    _hasRouted = true;
    final target = switch (resolvedUser.role) {
      AppUserRole.customer => '/customer',
      AppUserRole.owner => '/owner',
      AppUserRole.admin => '/admin',
    };
    debugPrint('[BUSGO STARTUP] Navigating to: $target');
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _logSplashMetrics(constraints);

        final safeBottomInset = MediaQuery.paddingOf(context).bottom;

        return DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF0B3D64)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  _splashAssetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('[BUSGO SPLASH] Image failed to load: $error');
                    return const ColoredBox(
                      color: Color(0xFF0B3D64),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24 + safeBottomInset,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.72,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Loading...',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
