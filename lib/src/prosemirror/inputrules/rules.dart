import 'inputrules.dart';

final InputRule emDash = InputRule(RegExp(r'--$'), '—', inCodeMark: false);
final InputRule ellipsis = InputRule(RegExp(r'\.\.\.$'), '…', inCodeMark: false);
final InputRule openDoubleQuote = InputRule(RegExp(r'''(?:^|[\s\{\[\(\<'"\u2018\u201C])(")$'''), '“', inCodeMark: false);
final InputRule closeDoubleQuote = InputRule(RegExp(r'"$'), '”', inCodeMark: false);
final InputRule openSingleQuote = InputRule(RegExp(r'''(?:^|[\s\{\[\(\<'"\u2018\u201C])(')$'''), '‘', inCodeMark: false);
final InputRule closeSingleQuote = InputRule(RegExp(r"'$"), '’', inCodeMark: false);

final List<InputRule> smartQuotes = [openDoubleQuote, closeDoubleQuote, openSingleQuote, closeSingleQuote];
