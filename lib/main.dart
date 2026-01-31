import 'package:flutter/material.dart';
// Using a local evaluator (shunting-yard) instead of the external API to avoid
// compatibility issues while keeping the dependency available in pubspec.

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator - Josh Kleinberg',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expr = ''; // expression used for evaluation (no spaces)
  String _display = ''; // human-readable display (with spaces around operators)
  String _accumulator = ''; // shows the ongoing expression or final result

  // no external parser in use; we evaluate expressions with shunting-yard

  static const operators = ['+', '-', '*', '/'];

  bool _isOperator(String ch) => operators.contains(ch);

  void _appendDigit(String d) {
    setState(() {
      _expr += d;
      _display += d;
      _accumulator = _display;
    });
  }

  void _appendOperator(String op) {
    setState(() {
      if (_expr.isEmpty) {
        // allow unary minus at start
        if (op == '-') {
          _expr = '-';
          _display = '-';
          _accumulator = _display;
        }
        return;
      }

      final last = _expr[_expr.length - 1];
      if (_isOperator(last)) {
        // replace last operator
        _expr = _expr.substring(0, _expr.length - 1) + op;
        // update display similarly (replace last operator token)
        _display = _display.trimRight();
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1) + op;
        } else {
          _display = op;
        }
      } else {
        _expr += op;
        _display += ' $op ';
      }
      _accumulator = _display;
    });
  }

  void _clearAll() {
    setState(() {
      _expr = '';
      _display = '';
      _accumulator = '';
    });
  }

  String _formatResult(dynamic r) {
    if (r == null) return 'null';
    if (r is int) return r.toString();
    if (r is double) {
      if (r.isInfinite) return 'Infinity';
      if (r.isNaN) return 'NaN';
      if (r == r.toInt()) return r.toInt().toString();
      // trim to max 10 decimal places
      var s = r.toStringAsFixed(10);
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
      return s;
    }
    return r.toString();
  }

  void _evaluate() {
    setState(() {
      if (_expr.isEmpty) return;
      try {
        final result = _evalExpression(_expr);
        if (result is num && result.isInfinite) {
          _accumulator = '${_display} = Error (division by zero)';
          _expr = '';
          _display = '';
          return;
        }
        final formatted = _formatResult(result);
        _accumulator = '${_display} = $formatted';
        _expr = formatted;
        _display = formatted;
      } catch (e) {
        _accumulator = '${_display} = Error';
        _expr = '';
        _display = '';
      }
    });
  }

  dynamic _evalExpression(String s) {
    // Tokenize
    final tokens = <String>[];
    var buf = '';
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) || ch == '.') {
        buf += ch;
        continue;
      }
      if (operators.contains(ch)) {
        // detect unary minus
        if (ch == '-' && (i == 0 || operators.contains(s[i - 1]))) {
          buf += ch; // part of number
          continue;
        }
        if (buf.isNotEmpty) {
          tokens.add(buf);
          buf = '';
        }
        tokens.add(ch);
        continue;
      }
      // ignore other chars (whitespace etc.)
    }
    if (buf.isNotEmpty) tokens.add(buf);

    // Shunting-yard to RPN
    final out = <String>[];
    final ops = <String>[];
    int precedence(String o) {
      if (o == '+' || o == '-') return 1;
      if (o == '*' || o == '/') return 2;
      return 0;
    }
    for (final t in tokens) {
      if (t.isEmpty) continue;
      if (operators.contains(t) && t.length == 1) {
        while (ops.isNotEmpty && precedence(ops.last) >= precedence(t)) {
          out.add(ops.removeLast());
        }
        ops.add(t);
      } else {
        out.add(t);
      }
    }
    while (ops.isNotEmpty) out.add(ops.removeLast());

    // Evaluate RPN
    final stack = <double>[];
    for (final t in out) {
      if (operators.contains(t) && t.length == 1) {
        if (stack.length < 2) throw Exception('Malformed expression');
        final b = stack.removeLast();
        final a = stack.removeLast();
        double res;
        switch (t) {
          case '+':
            res = a + b;
            break;
          case '-':
            res = a - b;
            break;
          case '*':
            res = a * b;
            break;
          case '/':
            if (b == 0) throw Exception('div0');
            res = a / b;
            break;
          default:
            throw Exception('Unknown operator');
        }
        stack.add(res);
      } else {
        stack.add(double.parse(t));
      }
    }
    if (stack.length != 1) throw Exception('Malformed expression');
    final result = stack.first;
    if (result == result.toInt()) return result.toInt();
    return result;
  }

  Widget _buildButton(String label, {Color? bgColor, Color? fgColor, void Function()? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor ?? Colors.grey[400],
          foregroundColor: fgColor ?? Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.all(18),
        ),
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '7', '8', '9', '/',
      '4', '5', '6', '*',
      '1', '2', '3', '-',
      '0', 'C', '=', '+',
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Calculator - Josh Kleinberg'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _accumulator.isEmpty ? _display : _accumulator,
                        style: const TextStyle(fontSize: 22, color: Colors.black87),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 5,
              child: GridView.count(
                crossAxisCount: 4,
                childAspectRatio: 1.25,
                children: buttons.map((b) {
                  if (b == 'C') {
                    return _buildButton(b, bgColor: Colors.orange, onTap: _clearAll);
                  } else if (b == '=') {
                    return _buildButton(b, bgColor: Colors.orange, onTap: _evaluate);
                  } else if (operators.contains(b)) {
                    return _buildButton(b, bgColor: Colors.orange, onTap: () => _appendOperator(b));
                  } else {
                    return _buildButton(b, bgColor: Colors.grey[800], onTap: () => _appendDigit(b));
                  }
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
