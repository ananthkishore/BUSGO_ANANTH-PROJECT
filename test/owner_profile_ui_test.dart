import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/features/owner/owner_dashboard_screen.dart';

void main() {
  test('owner profile helpers use the real owner name safely', () {
    expect(OwnerDashboardScreen.profileInitials('Kishore Kumar'), 'KK');
    expect(OwnerDashboardScreen.profileInitials('   '), 'O');
    expect(OwnerDashboardScreen.safeDisplayName('  Kishore  '), 'Kishore');
    expect(OwnerDashboardScreen.safeDisplayName('   '), 'there');
  });
}
