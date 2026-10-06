import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_roles.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/booking_details_screen.dart';
import '../features/admin/owner_details_screen.dart';
import '../features/admin/support_inbox_screen.dart';
import '../models/bus_model.dart';
import '../models/booking_request_model.dart';
import '../models/user_model.dart';
import '../models/bus_search_query.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/customer/customer_dashboard_screen.dart';
import '../features/customer/bus_search_screen.dart';
import '../features/customer/bus_details_screen.dart';
import '../features/customer/request_sent_screen.dart';
import '../features/customer/request_trip_screen.dart';
import '../features/customer/payment_screen.dart';
import '../features/customer/trip_details_screen.dart';
import '../features/payment/payment_details_screen.dart';
import '../features/owner/owner_dashboard_screen.dart';
import '../features/owner/payout_information_screen.dart';
import '../features/owner/owner_message_screen.dart';
import '../features/owner/add_bus_screen.dart';
import '../features/owner/request_details_screen.dart';
import '../features/owner/bus_management_details_screen.dart';
import '../features/owner/edit_bus_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/help_support_screen.dart';
import '../features/profile/legal_document_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/profile/support_conversation_screen.dart';
import '../features/splash/splash_screen.dart';
import '../providers/auth_provider.dart' as busgo_auth;
import '../repositories/booking_request_repository.dart';
import '../repositories/bus_repository.dart';
import '../widgets/busgo_ui.dart';

String? resolveDeepLinkRedirectLocation(String? rawPath) {
  final path = (rawPath ?? '').trim();
  if (path.isEmpty || path == '/' || path == '/login' || path == '/register') {
    return null;
  }
  if (path == '/forgot-password' || path == '/splash') return null;

  const deepLinkPrefixes = <String>[
    '/booking/',
    '/trip/',
    '/bus/',
    '/payment/',
    '/review/',
  ];

  for (final prefix in deepLinkPrefixes) {
    if (path.startsWith(prefix)) {
      return path;
    }
  }

  return null;
}

GoRouter createAppRouter(busgo_auth.AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation: '/splash',
    redirect: (context, state) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final isLoading = authProvider.isLoading;
      final isAuthenticated =
          firebaseUser != null || authProvider.isAuthenticated;
      final user = authProvider.currentUser;
      final route = state.matchedLocation;
      final deepLinkPath = resolveDeepLinkRedirectLocation(state.uri.path);

      debugPrint(
        '[ROUTER] route=$route isLoading=$isLoading authenticated=$isAuthenticated firebaseUser=${firebaseUser?.uid ?? 'null'} providerUser=${user?.uid ?? 'null'} deepLink=$deepLinkPath',
      );

      if (route == '/splash') return null;

      if (firebaseUser == null && !authProvider.isAuthenticated) {
        if (route == '/login' ||
            route == '/register' ||
            route == '/forgot-password' ||
            route == '/splash') {
          return null;
        }
        if (deepLinkPath != null) {
          return '/login?redirect=${Uri.encodeComponent(deepLinkPath)}';
        }
        return '/login';
      }

      if (isLoading && user == null) {
        return null;
      }

      final resolvedUser = authProvider.currentUser;
      if (resolvedUser == null) {
        return null;
      }

      final targetRoute = switch (resolvedUser.role) {
        AppUserRole.customer => '/customer',
        AppUserRole.owner => '/owner',
        AppUserRole.admin => '/admin',
      };

      final publicRoutes = {
        '/login',
        '/register',
        '/forgot-password',
        '/splash',
      };

      if (publicRoutes.contains(route)) {
        return targetRoute;
      }

      if (route == '/customer' || route.startsWith('/customer/')) {
        if (resolvedUser.role != AppUserRole.customer) return targetRoute;
      }
      if (route == '/owner' || route.startsWith('/owner/')) {
        if (resolvedUser.role != AppUserRole.owner) return targetRoute;
      }
      if (route == '/admin' || route.startsWith('/admin/')) {
        if (resolvedUser.role != AppUserRole.admin) return targetRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: '/booking/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'];
          if (bookingId == null || bookingId.trim().isEmpty) {
            return const CustomerDashboardScreen();
          }

          return FutureBuilder<BookingRequestModel?>(
            future: context.read<BookingRequestRepository>().getById(bookingId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final request = snapshot.data;
              if (request == null) {
                return const CustomerDashboardScreen();
              }

              final userRole = context
                  .read<busgo_auth.AuthProvider>()
                  .currentUser
                  ?.role;
              switch (userRole) {
                case AppUserRole.customer:
                  return TripDetailsScreen(request: request);
                case AppUserRole.owner:
                  return OwnerRequestDetailsScreen(request: request);
                case AppUserRole.admin:
                  return AdminBookingDetailsScreen(request: request);
                default:
                  return const LoginScreen();
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/trip/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'];
          if (tripId == null || tripId.trim().isEmpty) {
            return const CustomerDashboardScreen();
          }

          return FutureBuilder<BookingRequestModel?>(
            future: context.read<BookingRequestRepository>().getById(tripId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final request = snapshot.data;
              if (request == null) {
                return const CustomerDashboardScreen();
              }

              return TripDetailsScreen(request: request);
            },
          );
        },
      ),
      GoRoute(
        path: '/payment/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'];
          if (bookingId == null || bookingId.trim().isEmpty) {
            return const CustomerDashboardScreen();
          }

          return FutureBuilder<BookingRequestModel?>(
            future: context.read<BookingRequestRepository>().getById(bookingId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final request = snapshot.data;
              if (request == null) {
                return const CustomerDashboardScreen();
              }

              return PaymentScreen(request: request);
            },
          );
        },
      ),
      GoRoute(
        path: '/review/:reviewId',
        builder: (context, state) {
          final reviewId = state.pathParameters['reviewId'];
          if (reviewId == null || reviewId.trim().isEmpty) {
            return const CustomerDashboardScreen();
          }

          return FutureBuilder<BookingRequestModel?>(
            future: context.read<BookingRequestRepository>().getById(reviewId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final request = snapshot.data;
              if (request == null) {
                return const CustomerDashboardScreen();
              }

              return TripDetailsScreen(request: request);
            },
          );
        },
      ),
      GoRoute(
        path: '/bus/:busId',
        builder: (context, state) {
          final busId = state.pathParameters['busId'];
          if (busId == null || busId.trim().isEmpty) {
            return const CustomerDashboardScreen();
          }

          return FutureBuilder<BusModel?>(
            future: context.read<BusRepository>().getById(busId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final bus = snapshot.data;
              if (bus == null) {
                return const CustomerDashboardScreen();
              }
              return BusDetailsScreen(bus: bus);
            },
          );
        },
      ),
      GoRoute(
        path: '/customer/search',
        builder: (context, state) => BusSearchScreen(
          query: state.extra is BusSearchQuery
              ? state.extra as BusSearchQuery
              : null,
        ),
      ),
      GoRoute(
        path: '/customer/request',
        builder: (context, state) {
          final bus = state.extra;
          if (bus is! BusModel) return const BusSearchScreen();
          return RequestTripScreen(bus: bus);
        },
      ),
      GoRoute(
        path: '/customer/bus-details',
        builder: (context, state) {
          final bus = state.extra;
          if (bus is! BusModel) return const BusSearchScreen();
          return BusDetailsScreen(bus: bus);
        },
      ),
      GoRoute(
        path: '/customer/request-sent',
        builder: (context, state) => const RequestSentScreen(),
      ),
      GoRoute(
        path: '/customer/trip-details',
        builder: (context, state) {
          final request = state.extra;
          if (request is! BookingRequestModel) {
            return const CustomerDashboardScreen();
          }
          return TripDetailsScreen(request: request);
        },
      ),
      GoRoute(
        path: '/customer/payment',
        builder: (context, state) {
          final request = state.extra;
          if (request is! BookingRequestModel) {
            return const CustomerDashboardScreen();
          }
          return PaymentScreen(request: request);
        },
      ),
      GoRoute(
        path: '/payment-details',
        builder: (context, state) {
          final request = state.extra;
          if (request is! BookingRequestModel) {
            return const PaymentDetailsUnavailableScreen();
          }
          return PaymentDetailsScreen(request: request);
        },
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/owner/payout-information',
        builder: (context, state) => const OwnerPayoutInformationScreen(),
      ),
      GoRoute(
        path: '/owner/add-bus',
        builder: (context, state) => const AddBusScreen(),
      ),
      GoRoute(
        path: '/owner/messages',
        builder: (context, state) => const OwnerMessageScreen(),
      ),
      GoRoute(
        path: '/owner/request-details',
        builder: (context, state) {
          final request = state.extra;
          if (request is! BookingRequestModel) {
            return const _OwnerRouteArgumentError(
              title: 'Request details unavailable',
              message:
                  'The booking reference was missing or invalid. Return to Requests and try again.',
            );
          }
          return OwnerRequestDetailsScreen(request: request);
        },
      ),
      GoRoute(
        path: '/owner/bus-details',
        builder: (context, state) {
          final busId = state.extra;
          if (busId is! String || busId.trim().isEmpty) {
            return const _OwnerRouteArgumentError(
              title: 'Bus details unavailable',
              message:
                  'The bus reference was missing or invalid. Return to My Buses and try again.',
            );
          }
          return OwnerBusManagementDetailsScreen(busId: busId);
        },
      ),
      GoRoute(
        path: '/owner/edit-bus',
        builder: (context, state) {
          final busId = state.extra;
          if (busId is! String || busId.trim().isEmpty) {
            return const OwnerDashboardScreen();
          }
          return OwnerEditBusScreen(busId: busId);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/support',
        builder: (context, state) => const AdminSupportInboxScreen(),
      ),
      GoRoute(
        path: '/admin/booking-details',
        builder: (context, state) {
          final request = state.extra;
          if (request is! BookingRequestModel) {
            return const AdminDashboardScreen();
          }
          return AdminBookingDetailsScreen(request: request);
        },
      ),
      GoRoute(
        path: '/admin/owner-details',
        builder: (context, state) {
          final owner = state.extra;
          if (owner is! AppUser) {
            return const AdminDashboardScreen();
          }
          return AdminOwnerDetailsScreen(owner: owner);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/support/:conversationId',
        builder: (context, state) => SupportConversationScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Terms & Conditions',
          sections: [
            LegalSection(
              heading: 'Introduction',
              body:
                  'BUSGO provides a digital platform that connects customers, bus owners, and administrators for whole-bus travel bookings. By using our platform, you agree to use the service responsibly and lawfully.',
            ),
            LegalSection(
              heading: 'Booking responsibility',
              body:
                  'Customers are responsible for providing accurate pickup, destination, trip dates, and passenger counts. Owners are responsible for valid bus information and safe operation. BUSGO administrators review high-risk or incomplete requests before confirmation.',
            ),
            LegalSection(
              heading: 'Service availability',
              body:
                  'BUSGO does not guarantee an available bus for every requested trip until a booking is confirmed. Availability, pricing, and approval are subject to verification and operational conditions.',
            ),
          ],
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Privacy Policy',
          sections: [
            LegalSection(
              heading: 'Information we use',
              body:
                  'We collect the information needed to create and manage your account, process trip requests, communicate updates, and maintain a secure service experience. This includes profile details, contact details, trip data, and account security information.',
            ),
            LegalSection(
              heading: 'How we use it',
              body:
                  'Information is used to authenticate users, provide booking support, maintain trip records, approve services, and deliver notifications relevant to your account and travel needs.',
            ),
            LegalSection(
              heading: 'Data safety',
              body:
                  'Passwords are never stored in Firestore. Profile images are stored in Firebase Storage and linked through the user profile record. Access is restricted to authenticated users and role-based rules.',
            ),
          ],
        ),
      ),
      GoRoute(
        path: '/legal/cancellation',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Cancellation & Refund Policy',
          sections: [
            LegalSection(
              heading: 'Request changes',
              body:
                  'Customers may request trip changes or cancellations through the app before final confirmation. Some requests may be subject to owner or admin review depending on timing and trip status.',
            ),
            LegalSection(
              heading: 'Refunds',
              body:
                  'Refund eligibility depends on the booking status, timing of the cancellation, and the conditions associated with the confirmed bus and route. BUSGO may offer partial or full refunds where relevant and approved.',
            ),
            LegalSection(
              heading: 'Operational disputes',
              body:
                  'Any concerns about a cancellation, refund, or booking outcome should be raised through BUSGO support and will be reviewed by the appropriate team member.',
            ),
          ],
        ),
      ),
      GoRoute(
        path: '/legal/agreement',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'User Agreement',
          about: true,
          sections: [
            LegalSection(
              heading: 'Agreement',
              body:
                  'This agreement outlines the responsibilities of BUSGO customers, owners, and admins when using the platform. All parties are expected to use the service with honesty, respect, and good faith.',
            ),
            LegalSection(
              heading: 'Platform integrity',
              body:
                  'BUSGO may suspend or restrict access where a user attempts fraud, abuse, impersonation, or behavior that threatens platform integrity or the safety of other users.',
            ),
            LegalSection(
              heading: 'Updates',
              body:
                  'BUSGO may update these terms, policies, or service conditions from time to time. Continued use of the platform means you accept the latest applicable version.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _OwnerRouteArgumentError extends StatelessWidget {
  const _OwnerRouteArgumentError({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/owner');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: BusGoErrorState(title: title, message: message, onRetry: goBack),
      ),
    );
  }
}

extension AuthRouterContext on BuildContext {
  void goToRoleHome(AppUserRole role) {
    final target = switch (role) {
      AppUserRole.customer => '/customer',
      AppUserRole.owner => '/owner',
      AppUserRole.admin => '/admin',
    };
    go(target);
  }
}
