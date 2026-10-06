import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/app/theme.dart';
import 'package:flutter_application_12/widgets/busgo_ui.dart';

void main() {
  testWidgets('standard card borders use the BUSGO teal in both themes', (
    tester,
  ) async {
    for (final theme in [BusGoTheme.light, BusGoTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: BusGoSurface(child: SizedBox(height: 40))),
        ),
      );

      expect(theme.colorScheme.outline, BusGoTokens.teal);
      expect(theme.colorScheme.outlineVariant, BusGoTokens.teal);
      expect(theme.chipTheme.side?.color, BusGoTokens.teal);

      final surfaceContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BusGoSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = surfaceContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(border.top.color, BusGoTokens.teal);
    }
  });
}
