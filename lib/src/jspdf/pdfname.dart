/// Conversão de strings para PDF Name Objects.
///
/// Conforme PDF Reference 1.3 - Chapter 3.2.4 Name Object.
///
/// Portado de libs/pdfname.js do jsPDF.

/// Converte uma string para um PDF Name Object válido.
///
/// Caracteres fora da faixa ASCII imprimível (0x21-0x7E)
/// são codificados com # seguido do hexadecimal do char code.
///
/// Exemplo:
/// ```dart
/// toPDFName('Helvetica');     // → 'Helvetica'
/// toPDFName('My Font');       // → 'My#20Font'
/// toPDFName('Font(Bold)');    // → 'Font#28Bold#29'
/// ```
String toPDFName(String str) {
  // Verifica se contém caracteres não-ASCII
  for (var i = 0; i < str.length; i++) {
    if (str.codeUnitAt(i) > 0xFF) {
      throw ArgumentError(
        'Invalid PDF Name Object: $str, Only accept ASCII characters.',
      );
    }
  }

  final sb = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    final charCode = str.codeUnitAt(i);
    if (charCode < 0x21 ||
        charCode == 0x23 || // #
        charCode == 0x25 || // %
        charCode == 0x28 || // (
        charCode == 0x29 || // )
        charCode == 0x2F || // /
        charCode == 0x3C || // <
        charCode == 0x3E || // >
        charCode == 0x5B || // [
        charCode == 0x5D || // ]
        charCode == 0x7B || // {
        charCode == 0x7D || // }
        charCode > 0x7E) {
      final hexStr = charCode.toRadixString(16).padLeft(2, '0');
      sb.write('#$hexStr');
    } else {
      sb.write(str[i]);
    }
  }

  return sb.toString();
}
