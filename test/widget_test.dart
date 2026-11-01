import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kitapp_reader2/app.dart';
import 'package:kitapp_reader2/state/app_state.dart';

void main() {
  testWidgets('shows phone-only authentication', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppStateController.load();

    await tester.pumpWidget(KitappApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Kitapp'), findsOneWidget);
    expect(find.text('Телефон номериңиз менен кириңиз'), findsOneWidget);
    expect(find.text('Код алуу'), findsOneWidget);
  });
}
