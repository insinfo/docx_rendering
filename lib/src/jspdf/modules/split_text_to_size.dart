import '../jspdf.dart';

/// Plugin de divisão de texto por tamanho.
///
/// Divide strings longas em um array de linhas que cabem
/// dentro de uma largura máxima especificada.
///
/// Portado de modules/split_text_to_size.js do jsPDF.

/// Extensão do JsPdf para divisão de texto.
extension JsPdfSplitText on JsPdf {
  /// Divide [text] em linhas que cabem em [maxWidth] (em unidades do doc).
  ///
  /// Usa o tamanho de fonte e a fonte atual para calcular larguras.
  /// Retorna uma lista de strings, cada uma representando uma linha.
  List<String> splitTextToSize(String text, double maxWidth) {
    final fsize = getFontSize();
    final k = scaleFactor;

    // Converte maxWidth para unidades de fonte (pontos proporcionais)
    final fontUnitMaxLen = (1.0 * k * maxWidth) / fsize;

    // Divide primeiro por quebras de linha
    final paragraphs = text.split(RegExp(r'\r?\n'));

    final output = <String>[];
    for (final paragraph in paragraphs) {
      output.addAll(_splitParagraphIntoLines(paragraph, fontUnitMaxLen));
    }

    return output;
  }

  /// Divide um parágrafo em linhas baseado na largura máxima.
  List<String> _splitParagraphIntoLines(String text, double maxlen) {
    if (text.isEmpty) return [''];

    final words = text.split(' ');
    final spaceWidth = _getCharWidth(' ');

    var line = <String>[];
    final lines = <List<String>>[line];
    var lineLength = 0.0;
    var separatorLength = 0.0;

    for (final word in words) {
      final wordWidth = _getStringWidth(word);

      if (lineLength + separatorLength + wordWidth > maxlen &&
          line.isNotEmpty) {
        if (wordWidth > maxlen) {
          // Palavra muito longa — quebra forçada
          final chunks = _splitLongWord(
            word,
            maxlen - (lineLength + separatorLength),
            maxlen,
          );
          if (chunks.isNotEmpty) {
            line.add(chunks.first);
          }
          for (var c = 1; c < chunks.length - 1; c++) {
            lines.add([chunks[c]]);
          }
          if (chunks.length > 1) {
            line = [chunks.last];
            lines.add(line);
            lineLength = _getStringWidth(chunks.last);
          }
        } else {
          line = [word];
          lines.add(line);
          lineLength = wordWidth;
        }
        separatorLength = spaceWidth;
      } else {
        line.add(word);
        lineLength += separatorLength + wordWidth;
        separatorLength = spaceWidth;
      }
    }

    return lines.map((l) => l.join(' ')).toList();
  }

  /// Quebra uma palavra longa em pedaços.
  List<String> _splitLongWord(
    String word,
    double firstLineMaxLen,
    double maxLen,
  ) {
    final answer = <String>[];
    var i = 0;
    var workingLen = 0.0;

    // Primeiro pedaço (cabe na linha pendente)
    while (i < word.length &&
        workingLen + _getCharWidth(word[i]) < firstLineMaxLen) {
      workingLen += _getCharWidth(word[i]);
      i++;
    }
    answer.add(word.substring(0, i));

    // Pedaços restantes
    var startOfLine = i;
    workingLen = 0;
    while (i < word.length) {
      if (workingLen + _getCharWidth(word[i]) > maxLen) {
        answer.add(word.substring(startOfLine, i));
        workingLen = 0;
        startOfLine = i;
      }
      workingLen += _getCharWidth(word[i]);
      i++;
    }
    if (startOfLine != i) {
      answer.add(word.substring(startOfLine, i));
    }

    return answer;
  }

  /// Largura estimada de um caractere (proporcional a 1pt).
  double _getCharWidth(String char) {
    // Estimativa com base em fontes monoespacadas padrão
    // Em implementação completa, usaríamos métricas da fonte ativa
    return 0.55;
  }

  /// Largura estimada de uma string.
  double _getStringWidth(String text) {
    return text.length * _getCharWidth('m');
  }
}
