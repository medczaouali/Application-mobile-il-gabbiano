import 'package:flutter_test/flutter_test.dart';
import 'package:ilgabbiano/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Complaint flow', () {
    final db = DatabaseHelper();
    test('database helper instantiation', () async {
      expect(db, isNotNull);
    });
  });
}
