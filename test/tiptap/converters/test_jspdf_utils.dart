import 'package:docx_rendering/src/jspdf/utils.dart';
import 'package:test/test.dart';

void main() {
  test('formata o sinal do fuso conforme a especificacao PDF', () {
    expect(
      formatPdfTimeZoneOffset(const Duration(hours: -3)),
      "-03'00'",
    );
    expect(
      formatPdfTimeZoneOffset(const Duration(hours: 5, minutes: 30)),
      "+05'30'",
    );
    expect(formatPdfTimeZoneOffset(Duration.zero), "+00'00'");
  });
}
