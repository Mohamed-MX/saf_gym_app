import 'package:flutter_test/flutter_test.dart';
import 'package:saf_gym_app/main.dart';

void main() {
  testWidgets('SAF app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SAFApp());
    expect(find.text('SAF'), findsWidgets);
  });
}
