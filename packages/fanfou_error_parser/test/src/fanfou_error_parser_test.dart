import 'package:fanfou_error_parser/fanfou_error_parser.dart';
import 'package:test/test.dart';

void main() {
  group(parseFanfouApiError, () {
    test('extracts and trims the JSON error field', () {
      expect(
        parseFanfouApiError(
          '{"request":"/account/show.json",'
          '"error":" 参数错误 "}',
        ),
        '参数错误',
      );
    });

    test('returns null when there is no usable error field', () {
      expect(parseFanfouApiError(''), isNull);
      expect(parseFanfouApiError('{"error":"  "}'), isNull);
      expect(parseFanfouApiError('{"error":42}'), isNull);
      expect(parseFanfouApiError('<hash><request>/x</request></hash>'), isNull);
      expect(parseFanfouApiError('not structured'), isNull);
    });
  });
}
