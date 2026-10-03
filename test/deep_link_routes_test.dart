import 'package:flutter_application_12/app/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preserves app link routes when unauthenticated redirect is required',
    () {
      expect(
        resolveDeepLinkRedirectLocation('/booking/ABC123'),
        '/booking/ABC123',
      );
      expect(resolveDeepLinkRedirectLocation('/trip/TRIP-42'), '/trip/TRIP-42');
      expect(resolveDeepLinkRedirectLocation('/bus/BUS-99'), '/bus/BUS-99');
      expect(resolveDeepLinkRedirectLocation('/customer'), isNull);
      expect(resolveDeepLinkRedirectLocation('/login'), isNull);
    },
  );
}
