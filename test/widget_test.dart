import 'package:flutter_test/flutter_test.dart';

import 'package:edubooks/database_factory_init_stub.dart'
    if (dart.library.io) 'package:edubooks/database_factory_init_io.dart'
        as db_factory;
import 'package:edubooks/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  db_factory.configureDatabaseFactoryForPlatform();

  testWidgets('App loads grades screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EduBooksApp());
    expect(find.text('توزيع الكتب'), findsOneWidget);
  });
}
