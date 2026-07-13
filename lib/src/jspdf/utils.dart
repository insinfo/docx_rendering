import 'dart:math';

/// Utilitários internos do jsPDF portados para Dart.
///
/// Contém funções de formatação numérica, escape PDF e helpers diversos
/// que são usados em todo o core do gerador PDF.

/// Arredonda [number] para a [precision] informada,
/// removendo zeros à direita (ex: "1.50000" → "1.5").
String roundToPrecision(num number, int precision) {
  if (number.isNaN || precision.isNaN) {
    throw ArgumentError('Invalid argument passed to roundToPrecision');
  }
  return number.toStringAsFixed(precision).replaceAll(RegExp(r'0+$'), '');
}

/// High-precision float com precisão fixa.
String Function(num) createHpf(dynamic floatPrecision) {
  if (floatPrecision is int) {
    return (num number) {
      if (number.isNaN) {
        throw ArgumentError('Invalid argument passed to hpf');
      }
      return roundToPrecision(number, floatPrecision);
    };
  } else if (floatPrecision == 'smart') {
    return (num number) {
      if (number.isNaN) {
        throw ArgumentError('Invalid argument passed to hpf');
      }
      if (number > -1 && number < 1) {
        return roundToPrecision(number, 16);
      } else {
        return roundToPrecision(number, 5);
      }
    };
  } else {
    return (num number) {
      if (number.isNaN) {
        throw ArgumentError('Invalid argument passed to hpf');
      }
      return roundToPrecision(number, 16);
    };
  }
}

/// Formata número com 2 casas decimais.
String f2(num number) {
  if (number.isNaN) {
    throw ArgumentError('Invalid argument passed to f2');
  }
  return roundToPrecision(number, 2);
}

/// Formata número com 3 casas decimais.
String f3(num number) {
  if (number.isNaN) {
    throw ArgumentError('Invalid argument passed to f3');
  }
  return roundToPrecision(number, 3);
}

/// Padding de 2 dígitos (ex: 5 → "05").
String padd2(dynamic number) {
  return ('0${int.parse(number.toString())}').substring(
    ('0${int.parse(number.toString())}').length - 2,
  );
}

/// Padding hexadecimal de 2 dígitos.
String padd2Hex(dynamic hexString) {
  final s = hexString.toString();
  return ('00$s').substring(s.length);
}

/// Escapa caracteres especiais para strings PDF.
/// Substitui \, (, ) pelos escapes PDF correspondentes.
String pdfEscape(String text) {
  return text
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)')
      .replaceAll('\r', '\\r');
}

/// Converte uma [DateTime] para o formato de data PDF.
/// Formato: D:YYYYMMDDHHmmSS+HH'mm'
String convertDateToPDFDate(DateTime date) {
  final timeZoneString = formatPdfTimeZoneOffset(date.timeZoneOffset);

  return [
    'D:',
    date.year.toString(),
    padd2(date.month),
    padd2(date.day),
    padd2(date.hour),
    padd2(date.minute),
    padd2(date.second),
    timeZoneString,
  ].join('');
}

/// Formats a UTC offset using the PDF date suffix syntax (`+HH'mm'`).
///
/// Dart's [DateTime.timeZoneOffset] is local time minus UTC, so locations west
/// of Greenwich have a negative offset. This is the same sign convention used
/// by the PDF specification.
String formatPdfTimeZoneOffset(Duration offset) {
  final minutes = offset.inMinutes;
  final sign = minutes < 0 ? '-' : '+';
  final hour = minutes.abs() ~/ 60;
  final minute = minutes.abs() % 60;
  return "$sign${padd2(hour)}'${padd2(minute)}'";
}

/// Converte uma data PDF (string) de volta para [DateTime].
DateTime convertPDFDateToDate(String pdfDate) {
  final year = int.parse(pdfDate.substring(2, 6));
  final month = int.parse(pdfDate.substring(6, 8));
  final day = int.parse(pdfDate.substring(8, 10));
  final hour = int.parse(pdfDate.substring(10, 12));
  final minutes = int.parse(pdfDate.substring(12, 14));
  final seconds = int.parse(pdfDate.substring(14, 16));
  return DateTime(year, month, day, hour, minutes, seconds);
}

/// Gera um file ID aleatório de 32 caracteres hexadecimais.
String generateFileId() {
  const chars = 'ABCDEF0123456789';
  final rng = Random();
  return List.generate(32, (_) => chars[rng.nextInt(16)]).join();
}

/// Valida e normaliza fileId.
/// Se [value] é um hex válido de 32 chars, retorna em maiúsculas.
/// Caso contrário, gera um novo.
String normalizeFileId(String? value) {
  if (value != null && RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value)) {
    return value.toUpperCase();
  }
  return generateFileId();
}
