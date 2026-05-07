import 'package:flutter_test/flutter_test.dart';
import 'package:card_tcg_app/main.dart';

void main() {
  testWidgets('App renders navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(const CardTCGApp());
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
  });
}
