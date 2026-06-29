import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FacebookLinkService security contract', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/facebook_link_service.dart').readAsStringSync();
    });

    test('sends Facebook access tokens in the Authorization header', () {
      expect(source, isNot(contains("'access_token': tokenString")));
      expect(source, isNot(contains('"access_token": tokenString')));
      expect(source, contains("'Authorization': 'Bearer \$tokenString'"));
    });

    test('does not log Graph API response bodies', () {
      expect(
        source,
        isNot(contains('Graph API error: \${response.body}')),
      );
      expect(
        source,
        contains('Graph API error: status=\${response.statusCode}'),
      );
    });
  });
}
