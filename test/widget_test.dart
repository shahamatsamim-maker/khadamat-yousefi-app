import 'package:flutter_test/flutter_test.dart';
import 'package:yusufi_services_app/main.dart';

void main() {
  testWidgets('Yusufi app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const YusufiApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('خدمات یوسفی'), findsWidgets);
  });
}
