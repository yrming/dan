import 'package:dan/app/theme/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppSpacing, () {
    test('provides a ten logical pixel spacing token', () {
      expect(AppSpacing.space10, 10);
    });
  });
}
