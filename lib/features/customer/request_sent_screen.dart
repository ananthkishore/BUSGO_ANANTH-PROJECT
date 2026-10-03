import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/busgo_ui.dart';

class RequestSentScreen extends StatelessWidget {
  const RequestSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2141), Color(0xFF164B86)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB547),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: Color(0xFF081A33),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Request Sent Successfully',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your request is now with the bus owner.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                BusGoSurface(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF9A5B00),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'PENDING OWNER',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Waiting for bus owner approval',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      const BusGoTimeline(
                        steps: [
                          'Request sent',
                          'Owner approval',
                          'Admin review',
                          'Payment',
                          'Trip completed',
                          'Review',
                        ],
                        activeIndex: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/customer'),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Back to customer home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
