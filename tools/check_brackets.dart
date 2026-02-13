import 'dart:io';

void main() {
  final f = File('lib/main_screen.dart');
  final s = f.readAsStringSync();
  final stack = <Map<String, int>>[];
  int line = 1, col = 0;
  for (var i = 0; i < s.length; i++) {
    var c = s[i];
    if (c == '\n') {
      line++;
      col = 0;
      continue;
    }
    col++;
    if (c == '[' || c == '(' || c == '{')
      stack.add({'c': c.codeUnitAt(0), 'line': line, 'col': col});
    if (c == ']' || c == ')' || c == '}') {
      if (stack.isEmpty) {
        print('Unmatched closing $c at $line:$col');
        return;
      }
      var last = stack.removeLast();
      var open = String.fromCharCode(last['c']!);
      if ((open == '[' && c != ']') ||
          (open == '(' && c != ')') ||
          (open == '{' && c != '}')) {
        print(
          'Mismatched $open with $c at $line:$col (opened at ${last['line']}:${last['col']})',
        );
        return;
      }
    }
  }
  if (stack.isNotEmpty) {
    for (var e in stack)
      print(
        'Unclosed ${String.fromCharCode(e['c']!)} opened at ${e['line']}:${e['col']}',
      );
  } else {
    print('All brackets matched.');
  }
}
