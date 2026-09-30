import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/forced_update.dart';

void main() {
  group('compareSemver', () {
    test('orders major.minor.patch', () {
      expect(compareSemver('1.0.0', '1.0.1'), lessThan(0));
      expect(compareSemver('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareSemver('2.0.0', '2.0.0'), 0);
    });

    test('treats missing segments as zero', () {
      expect(compareSemver('1.0', '1.0.0'), 0);
      expect(compareSemver('1', '1.0.1'), lessThan(0));
    });
  });

  group('isForcedUpdateRequired', () {
    test('false when minimum is unset', () {
      expect(
        isForcedUpdateRequired(current: '1.0.0', minimum: null),
        isFalse,
      );
      expect(
        isForcedUpdateRequired(current: '1.0.0', minimum: ''),
        isFalse,
      );
    });

    test('true only when current is older', () {
      expect(
        isForcedUpdateRequired(current: '1.0.1', minimum: '1.0.2'),
        isTrue,
      );
      expect(
        isForcedUpdateRequired(current: '1.0.2', minimum: '1.0.2'),
        isFalse,
      );
      expect(
        isForcedUpdateRequired(current: '1.1.0', minimum: '1.0.2'),
        isFalse,
      );
    });
  });
}
