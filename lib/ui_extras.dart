import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

enum AmountArtwork { shopping, wallet }

/// Векторные логотипы банковских карт (MasterCard / VISA) для жёлтых карточек
class PaymentCardPainter extends CustomPainter {
  final bool isMasterCard;
  const PaymentCardPainter({required this.isMasterCard});

  @override
  void paint(Canvas canvas, Size size) {
    // Лёгкий блик в верхнем левом углу карточки
    final sheen = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sheen);

    // Миниатюрный чип слева
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.11, size.height * 0.24, size.width * 0.16, size.height * 0.24),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(chipRect, Paint()..color = const Color(0xCCFEF08A));

    if (isMasterCard) {
      final cy = size.height * 0.56;
      final r = size.height * 0.25;
      final cxLeft = size.width * 0.50;
      final cxRight = size.width * 0.69;

      // Левый красный круг
      canvas.drawCircle(Offset(cxLeft, cy), r, Paint()..color = const Color(0xFFEB001B));
      // Правый оранжево-жёлтый круг
      canvas.drawCircle(Offset(cxRight, cy), r, Paint()..color = const Color(0xFFF79E1B).withOpacity(0.92));

      // Зона пересечения (линза) более насыщенного оранжевого цвета
      final leftPath = Path()..addOval(Rect.fromCircle(center: Offset(cxLeft, cy), radius: r));
      final rightPath = Path()..addOval(Rect.fromCircle(center: Offset(cxRight, cy), radius: r));
      final intersection = Path.combine(PathOperation.intersect, leftPath, rightPath);
      canvas.drawPath(intersection, Paint()..color = const Color(0xFFFF5F00));
    } else {
      // Чёткий логотип VISA
      final tp = TextPainter(
        text: TextSpan(
          text: 'VISA',
          style: TextStyle(
            color: const Color(0xFF1A1F71),
            fontSize: size.height * 0.36,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.4,
            shadows: const [
              Shadow(color: Color(0x55FFFFFF), offset: Offset(0, 0.8), blurRadius: 1),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width - tp.width - size.width * 0.12, size.height - tp.height - size.height * 0.14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PaymentCardPainter oldDelegate) => oldDelegate.isMasterCard != isMasterCard;
}

/// Цветной векторный мини-калькулятор в стиле iPhone
class IphoneCalcIconPainter extends CustomPainter {
  const IphoneCalcIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 18.0;
    final sy = size.height / 20.0;
    canvas.save();
    canvas.scale(sx, sy);

    // Корпус калькулятора
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(1, 0.5, 16, 19), const Radius.circular(3.5));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF1C1C1E));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    // Экран сверху
    final screen = RRect.fromRectAndRadius(const Rect.fromLTWH(2.8, 2.3, 12.4, 4.0), const Radius.circular(1.2));
    canvas.drawRRect(screen, Paint()..color = const Color(0xFF2C2C2E));
    // Имитация цифр на экране
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(9.5, 3.6, 4.6, 1.5), const Radius.circular(0.6)),
      Paint()..color = const Color(0xFF4ADE80),
    );

    // Сетка кнопок 4x3
    const cols = [3.8, 7.2, 10.6, 14.0];
    const rows = [8.5, 11.8, 15.1, 17.8];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < cols.length; c++) {
        final isOrange = c == 3;
        final isTopLight = r == 0 && c < 3;
        final color = isOrange
            ? const Color(0xFFFF9F0A)
            : isTopLight
                ? const Color(0xFFA5A5A7)
                : const Color(0xFF505052);
        if (r == 3 && c == 0) continue; // нулевая кнопка двойной ширины
        if (r == 3 && c == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(2.6, rows[r] - 1.1, 5.8, 2.1), const Radius.circular(1.0)),
            Paint()..color = color,
          );
        } else {
          canvas.drawCircle(Offset(cols[c], rows[r]), 1.15, Paint()..color = color);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FintechAmountPainter extends CustomPainter {
  final AmountArtwork artwork;
  const FintechAmountPainter(this.artwork);
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 54, sy = size.height / 54;
    canvas.save();
    canvas.scale(sx, sy);
    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final bag = Paint()..color = const Color(0xFF65C8FF);
    final bagSide = Paint()..color = const Color(0xFF2874D8);
    final line = Paint()
      ..color = const Color(0xFFB9E8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (artwork == AmountArtwork.shopping) {
      final body = Path()
        ..moveTo(9, 19)
        ..quadraticBezierTo(9, 16, 13, 16)
        ..lineTo(40, 16)
        ..quadraticBezierTo(44, 16, 44, 20)
        ..lineTo(41, 43)
        ..quadraticBezierTo(40, 47, 36, 47)
        ..lineTo(13, 45)
        ..quadraticBezierTo(9, 44, 9, 40)
        ..close();
      canvas.drawPath(body.shift(const Offset(0, 2)), shadow);
      canvas.drawPath(body, bag);
      canvas.drawPath(Path()..moveTo(34, 17)..lineTo(41, 18)..lineTo(38, 44)..lineTo(32, 46)..close(), bagSide);
      canvas.drawPath(Path()..moveTo(17, 19)..cubicTo(17, 3, 35, 3, 36, 19), line);
      canvas.drawPath(
        Path()..moveTo(23, 19)..cubicTo(23, 10, 31, 10, 31, 19),
        Paint()
          ..color = const Color(0xFF9B8CFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      final pad = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 29, 18, 13), const Radius.circular(4));
      canvas.drawRRect(pad, Paint()..color = const Color(0xFF153E8A));
      canvas.drawCircle(const Offset(33, 35), 1.5, Paint()..color = const Color(0xFF6DE5FF));
      canvas.drawCircle(const Offset(40, 33), 1.3, Paint()..color = const Color(0xFFFFD56A));
      canvas.drawLine(const Offset(36, 32), const Offset(36, 38), Paint()..color = Colors.white..strokeWidth = 1.2);
      canvas.drawLine(const Offset(33, 35), const Offset(39, 35), Paint()..color = Colors.white..strokeWidth = 1.2);
    } else {
      final wallet = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 17, 36, 27), const Radius.circular(7));
      canvas.drawRRect(wallet.shift(const Offset(0, 2)), shadow);
      canvas.drawRRect(
        wallet,
        Paint()..shader = const LinearGradient(colors: [Color(0xFF7DE7B0), Color(0xFF16A34A)]).createShader(const Rect.fromLTWH(8, 17, 36, 27)),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, 14, 30, 8), const Radius.circular(5)), Paint()..color = const Color(0xFFFFD36A));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(34, 26, 15, 13), const Radius.circular(4)), Paint()..color = const Color(0xFF16834C));
      canvas.drawCircle(const Offset(39, 38), 10, Paint()..color = const Color(0xFFE9B84E));
      canvas.drawCircle(const Offset(39, 37), 7.5, Paint()..color = const Color(0xFFFFD76A));
      final tp = TextPainter(
        text: const TextSpan(text: '₴', style: TextStyle(color: Color(0xFF9B6419), fontSize: 11, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(35, 30));
      canvas.drawLine(
        const Offset(13, 21),
        const Offset(31, 21),
        Paint()
          ..color = const Color(0xFFB8FFD1)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FintechAmountPainter old) => old.artwork != artwork;
}

class CountryFlagPainter extends CustomPainter {
  final String country;
  const CountryFlagPainter(this.country);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(2.5));
    canvas.save();
    canvas.clipRRect(r);
    if (country == 'ua') {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), Paint()..color = const Color(0xFF1677E8));
      canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), Paint()..color = const Color(0xFFFFD43B));
    } else {
      final h = size.height / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h), Paint()..color = const Color(0xFF00A3DD));
      canvas.drawRect(Rect.fromLTWH(0, h, size.width, h), Paint()..color = const Color(0xFFED2939));
      canvas.drawRect(Rect.fromLTWH(0, h * 2, size.width, h), Paint()..color = const Color(0xFF3F9C35));
      final cx = size.width * .43, cy = size.height * .5, rad = size.height * .22;
      canvas.drawCircle(Offset(cx, cy), rad, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx + rad * .38, cy - rad * .08), rad * .82, Paint()..color = const Color(0xFFED2939));
      final star = Path();
      for (var i = 0; i < 16; i++) {
        final a = -math.pi / 2 + i * math.pi / 8;
        final rr = i.isEven ? size.height * .105 : size.height * .045;
        final pt = Offset(size.width * .68 + math.cos(a) * rr, size.height * .5 + math.sin(a) * rr);
        if (i == 0) {
          star.moveTo(pt.dx, pt.dy);
        } else {
          star.lineTo(pt.dx, pt.dy);
        }
      }
      star.close();
      canvas.drawPath(star, Paint()..color = Colors.white);
    }
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
  }

  @override
  bool shouldRepaint(covariant CountryFlagPainter old) => old.country != country;
}

class RateSparklinePainter extends CustomPainter {
  final List<double> values;
  RateSparklinePainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final points = values.length < 2 ? [.35, .52, .42, .68, .60, .82, .72, .95] : values;
    final minValue = points.reduce((a, b) => a < b ? a : b), maxValue = points.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.000001 ? 1.0 : (maxValue - minValue);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - 5 - ((points[i] - minValue) / span) * (size.height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final previousX = size.width * (i - 1) / (points.length - 1);
        final previousY = size.height - 5 - ((points[i - 1] - minValue) / span) * (size.height - 10);
        final mid = (previousX + x) / 2;
        path.cubicTo(mid, previousY, mid, y, x, y);
      }
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    final rect = Offset.zero & size;
    final shader = const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF34D399)]).createShader(rect);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x55A855F7), Color(0x0034D399)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant RateSparklinePainter oldDelegate) => oldDelegate.values != values;
}

class MiniCalcDialog extends StatefulWidget {
  final double autoServiceFee;
  final ValueChanged<double>? onAddToPurchase;
  const MiniCalcDialog({
    super.key,
    this.autoServiceFee = 100.0,
    this.onAddToPurchase,
  });
  @override
  State<MiniCalcDialog> createState() => _MiniCalcDialogState();
}

class _MiniCalcDialogState extends State<MiniCalcDialog> {
  String expression = '0';
  String? error;
  String? lastAnswer;
  int addedCount = 0;

  static const _keys = <List<String>>[
    ['AC', '⌫', '(', ')'],
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['±', '0', '.', '+'],
    ['%', '00', '=', ''],
  ];

  bool get _endsWithOperator => expression.isNotEmpty && RegExp(r'[+−×÷.]$').hasMatch(expression);

  double? _resolveCurrentAmount() {
    try {
      final value = _ExpressionParser(expression).parse();
      if (!value.isFinite || value <= 0) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  void _sendToBasket() {
    final amount = _resolveCurrentAmount();
    if (amount == null) {
      AppHaptics.trigger(HapticMode.light);
      setState(() => error = 'Введите сумму больше 0');
      return;
    }
    AppHaptics.trigger();
    widget.onAddToPurchase?.call(amount);
    setState(() {
      addedCount++;
      expression = '0';
      lastAnswer = null;
      error = null;
    });
    final feeText = widget.autoServiceFee.toStringAsFixed(widget.autoServiceFee.truncateToDouble() == widget.autoServiceFee ? 0 : 2);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('+${_format(amount)} ₴ в покупку и +$feeText ₴ в услугу'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _press(String key) {
    AppHaptics.trigger(HapticMode.light);
    setState(() {
      error = null;
      if (key == 'AC') {
        expression = '0';
        lastAnswer = null;
        return;
      }
      if (key == '⌫') {
        expression = expression.length <= 1 ? '0' : expression.substring(0, expression.length - 1);
        lastAnswer = null;
        return;
      }
      if (key == '=') {
        try {
          final value = _ExpressionParser(expression).parse();
          if (!value.isFinite) throw const FormatException('Деление на ноль');
          final formatted = _format(value);
          lastAnswer = formatted;
          expression = formatted;
        } catch (_) {
          error = 'Проверьте выражение';
        }
        return;
      }
      if (key == '±') {
        if (expression == '0') return;
        expression = expression.startsWith('−') ? expression.substring(1) : '−($expression)';
        return;
      }
      if (key == '%') {
        if (expression.isNotEmpty && RegExp(r'[0-9)]$').hasMatch(expression)) {
          expression += '%';
          lastAnswer = null;
        }
        return;
      }
      if (key == '.') {
        lastAnswer = null;
        final current = RegExp(r'([0-9]*\.?[0-9]*)$').firstMatch(expression)?.group(0) ?? '';
        if (current.contains('.')) return;
        expression = expression == '0' ? '0.' : '$expression.';
        return;
      }
      final isDigit = RegExp(r'^\d+$').hasMatch(key);
      final isOperator = const ['+', '−', '×', '÷'].contains(key);
      if (isOperator) {
        if (expression == '0' && key != '−') return;
        if (_endsWithOperator) {
          expression = expression.substring(0, expression.length - 1) + key;
        } else {
          expression += key;
        }
        lastAnswer = null;
        return;
      }
      if (isDigit) {
        if (expression == '0' || lastAnswer != null) {
          expression = key == '00' ? '0' : key;
        } else {
          expression += key;
        }
        lastAnswer = null;
        return;
      }
      if (key == '(' || key == ')') {
        if (expression == '0' && key == '(') {
          expression = '(';
        } else {
          expression += key;
        }
        lastAnswer = null;
      }
    });
  }

  String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) return value.toInt().toString();
    return value.toStringAsPrecision(10).replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  Future<void> _copyDisplay() async {
    AppHaptics.trigger();
    await Clipboard.setData(ClipboardData(text: expression));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Значение скопировано')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final feeStr = widget.autoServiceFee.toStringAsFixed(widget.autoServiceFee.truncateToDouble() == widget.autoServiceFee ? 0 : 2);
    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: () {
                      AppHaptics.trigger(HapticMode.light);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(child: Text('Калькулятор', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                  if (widget.onAddToPurchase != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton.tonal(
                        onPressed: _sendToBasket,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0x28F59E0B),
                          foregroundColor: const Color(0xFFFBBF24),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0x66F59E0B)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_basket_rounded, size: 19, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 2),
                            const Icon(Icons.monetization_on_rounded, size: 17, color: Color(0xFFFACC15)),
                            if (addedCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)),
                                child: Text('$addedCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  IconButton(tooltip: 'Копировать значение', onPressed: _copyDisplay, icon: const Icon(Icons.copy_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 132),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastAnswer != null) Text('Результат', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(expression, maxLines: 1, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                      ),
                      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 9.0;
                    final buttonHeight = ((constraints.maxHeight - spacing * 5) / 6).clamp(44.0, 82.0).toDouble();
                    return Column(
                      children: [
                        for (final row in _keys)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: row == _keys.last ? 0 : spacing),
                              child: Row(
                                children: [
                                  for (final key in row)
                                    if (key.isNotEmpty)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: SizedBox(
                                            height: buttonHeight,
                                            child: FilledButton.tonal(
                                              onPressed: () => _press(key),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: key == '='
                                                    ? scheme.primary
                                                    : (['+', '−', '×', '÷', '%'].contains(key) ? scheme.secondaryContainer : scheme.surfaceContainerHighest),
                                                foregroundColor: key == '=' ? scheme.onPrimary : scheme.onSurface,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                textStyle: TextStyle(fontSize: key.length > 1 ? 16 : 22, fontWeight: FontWeight.w700),
                                              ),
                                              child: Text(key),
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Корзинка с монетками добавляет сумму в покупку и +$feeStr ₴ в услугу',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressionParser {
  _ExpressionParser(String source)
      : _source = source.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-').replaceAll(',', '.');
  final String _source;
  int _index = 0;

  double parse() {
    final value = _sum();
    _spaces();
    if (_index != _source.length) throw const FormatException('Лишние символы');
    return value;
  }

  void _spaces() {
    while (_index < _source.length && _source[_index].trim().isEmpty) {
      _index++;
    }
  }

  bool _take(String char) {
    _spaces();
    if (_index < _source.length && _source[_index] == char) {
      _index++;
      return true;
    }
    return false;
  }

  double _sum() {
    var value = _product();
    while (true) {
      if (_take('+')) {
        value += _product();
      } else if (_take('-')) {
        value -= _product();
      } else {
        return value;
      }
    }
  }

  double _product() {
    var value = _unary();
    while (true) {
      if (_take('*')) {
        value *= _unary();
      } else if (_take('/')) {
        final divisor = _unary();
        if (divisor == 0) throw const FormatException('Деление на ноль');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _unary() {
    if (_take('+')) return _unary();
    if (_take('-')) return -_unary();
    var value = _atom();
    if (_take('%')) value /= 100;
    return value;
  }

  double _atom() {
    if (_take('(')) {
      final value = _sum();
      if (!_take(')')) throw const FormatException('Нет закрывающей скобки');
      return value;
    }
    _spaces();
    final start = _index;
    var dots = 0;
    while (_index < _source.length) {
      final c = _source[_index];
      if (c == '.') {
        dots++;
        if (dots > 1) break;
        _index++;
      } else if (RegExp(r'\d').hasMatch(c)) {
        _index++;
      } else {
        break;
      }
    }
    if (start == _index) throw const FormatException('Ожидалось число');
    return double.parse(_source.substring(start, _index));
  }
}

class TariffPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String initialPaymentSystem;
  final ValueChanged> onSave;
  const TariffPage({
    super.key,
    required this.data,
    this.initialPaymentSystem = 'visa',
    required this.onSave,
  });
  @override
  State<TariffPage> createState() => _TariffPageState();
}

class _TariffPageState extends State<TariffPage> {
  late Map<String, dynamic> data;
  late String paymentSystem;
  String tab = 'senders', routeSender = '', routeReceiver = '';
  final fields = <String, TextEditingController>{};
  bool routeVerified = false;
  String routeMode = 'add_on';

  String get _receiversKey => paymentSystem == 'mc' ? 'receivers_mc' : 'receivers';
  String get _routesKey => paymentSystem == 'mc' ? 'routes_mc' : 'routes';

  @override
  void initState() {
    super.initState();
    data = jsonDecode(jsonEncode(widget.data));
    paymentSystem = widget.initialPaymentSystem == 'mc' ? 'mc' : 'visa';
    routeSender = (data['senders'] as Map).keys.first;
    final rMap = data[_receiversKey] as Map<String, dynamic>;
    routeReceiver = rMap.keys.first;
    _loadRoute();
  }

  void _switchPaymentSystem(String ps) {
    if (paymentSystem == ps) {
      AppHaptics.trigger(HapticMode.light);
      return;
    }
    AppHaptics.trigger();
    _saveRoute();
    paymentSystem = ps;
    final rMap = data[_receiversKey] as Map<String, dynamic>;
    if (!rMap.containsKey(routeReceiver)) {
      routeReceiver = rMap.keys.first;
    }
    _loadRoute();
    setState(() {});
  }

  void _loadRoute() {
    final routesMap = data[_routesKey] as Map<String, dynamic>;
    final r = routesMap['$routeSender->$routeReceiver'] ?? {};
    final s = r['sender'] ?? {};
    final t = r['receiver'] ?? {};
    for (final k in [
      'percent_fee',
      'fixed_fee_azn',
      'conversion_fee_percent',
      'min_fee_azn',
      'max_fee_azn',
      'receiver_percent_fee',
      'fixed_fee_uah',
      'min_fee_uah',
      'max_fee_uah',
    ]) {
      fields[k]?.dispose();
    }
    fields.clear();
    for (final k in ['percent_fee', 'fixed_fee_azn', 'conversion_fee_percent', 'min_fee_azn', 'max_fee_azn']) {
      fields[k] = TextEditingController(text: s[k]?.toString() ?? (k.startsWith('min_') || k.startsWith('max_') ? '' : '0'));
    }
    for (final k in ['receiver_percent_fee', 'fixed_fee_uah', 'min_fee_uah', 'max_fee_uah']) {
      final src = k == 'receiver_percent_fee' ? 'percent_fee' : k;
      fields[k] = TextEditingController(text: t[src]?.toString() ?? (k.startsWith('min_') || k.startsWith('max_') ? '' : '0'));
    }
    routeMode = s['fee_mode'] ?? 'add_on';
    routeVerified = r['verified'] == true;
  }

  void _saveRoute() {
    final s = data['senders'][routeSender];
    final r = data[_receiversKey][routeReceiver];
    if (s == null || r == null) return;
    data[_routesKey]['$routeSender->$routeReceiver'] = {
      'sender': {
        'name': s['name'],
        'percent_fee': fields['percent_fee']!.text,
        'fixed_fee_azn': fields['fixed_fee_azn']!.text,
        'conversion_fee_percent': fields['conversion_fee_percent']!.text,
        'min_fee_azn': fields['min_fee_azn']!.text.isEmpty ? null : fields['min_fee_azn']!.text,
        'max_fee_azn': fields['max_fee_azn']!.text.isEmpty ? null : fields['max_fee_azn']!.text,
        'fee_mode': routeMode,
      },
      'receiver': {
        'name': r['name'],
        'percent_fee': fields['receiver_percent_fee']!.text,
        'fixed_fee_uah': fields['fixed_fee_uah']!.text,
        'min_fee_uah': fields['min_fee_uah']!.text.isEmpty ? null : fields['min_fee_uah']!.text,
        'max_fee_uah': fields['max_fee_uah']!.text.isEmpty ? null : fields['max_fee_uah']!.text,
      },
      'verified': routeVerified,
    };
  }

  Widget _editBankGroup(String group) {
    final actualGroup = group == 'receivers' ? _receiversKey : group;
    final map = data[actualGroup] as Map<String, dynamic>;
    final isSender = group == 'senders';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...map.entries.map((entry) {
          final key = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final names = isSender
              ? ['fixed_fee_azn', 'percent_fee', 'conversion_fee_percent', 'min_fee_azn', 'max_fee_azn']
              : ['fixed_fee_uah', 'percent_fee', 'min_fee_uah', 'max_fee_uah'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('${item['name']} [$key]${isSender ? '' : (paymentSystem == 'mc' ? ' • MC' : ' • Visa')}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ...names.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            key: ValueKey('${paymentSystem}_${actualGroup}_${key}_$f'),
                            initialValue: item[f]?.toString() ?? '',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _tariffLabel(f, !isSender),
                              hintText: f.startsWith('max_') ? 'пусто = без ограничения' : '0',
                            ),
                            onChanged: (v) => item[f] = v.isEmpty && f.startsWith('max_') ? null : (v.isEmpty ? '0' : v),
                          ),
                        ),
                      ),
                      if (isSender)
                        DropdownButtonFormField<String>(
                          value: item['fee_mode'] ?? 'add_on',
                          decoration: const InputDecoration(labelText: 'Способ удержания'),
                          items: const [
                            DropdownMenuItem(value: 'add_on', child: Text('Комиссия сверху (add_on)')),
                            DropdownMenuItem(value: 'deducted', child: Text('Удерживается (deducted)')),
                          ],
                          onChanged: (v) {
                            AppHaptics.trigger(HapticMode.light);
                            item['fee_mode'] = v;
                          },
                        ),
                      CheckboxListTile(
                        value: item['verified'] == true,
                        title: const Text('Тариф проверен и подтверждён'),
                        onChanged: (v) {
                          AppHaptics.trigger();
                          setState(() => item['verified'] = v == true);
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            AppHaptics.trigger();
                            setState(() {
                              map.remove(key);
                              (data[_routesKey] as Map).removeWhere((rk, _) => rk.toString().startsWith('$key->') || rk.toString().endsWith('->$key'));
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Удалить банк'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => _addBank(group),
          icon: const Icon(Icons.add),
          label: const Text('Добавить банк'),
        ),
      ],
    );
  }

  Future<void> _addBank(String group) async {
    AppHaptics.trigger(HapticMode.light);
    final name = TextEditingController(), key = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Новый банк'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
            const SizedBox(height: 8),
            TextField(controller: key, decoration: const InputDecoration(labelText: 'Уникальный ключ (латиница)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(c, false); }, child: const Text('Отмена')),
          FilledButton(onPressed: () { AppHaptics.trigger(); Navigator.pop(c, true); }, child: const Text('Добавить')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && key.text.trim().isNotEmpty) {
      final k = key.text.trim().toLowerCase().replaceAll(' ', '_');
      if (group == 'senders') {
        final map = data['senders'] as Map<String, dynamic>;
        if (map.containsKey(k)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Такой идентификатор уже существует')));
          return;
        }
        map[k] = senderTemplate(name.text.trim());
      } else {
        final visaMap = data['receivers'] as Map<String, dynamic>;
        final mcMap = data['receivers_mc'] as Map<String, dynamic>;
        if (visaMap.containsKey(k) || mcMap.containsKey(k)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Такой идентификатор уже существует')));
          return;
        }
        visaMap[k] = receiverTemplate(name.text.trim());
        mcMap[k] = receiverTemplate(name.text.trim());
      }
      setState(() {});
    }
  }

  Widget _routeEditor() {
    final send = data['senders'] as Map<String, dynamic>;
    final recv = data[_receiversKey] as Map<String, dynamic>;
    final psSuffix = paymentSystem == 'mc' ? ' [MC]' : ' [Visa]';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Индивидуальные правила для пары банков$psSuffix имеют приоритет над общими тарифами.'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: routeSender,
          decoration: const InputDecoration(labelText: 'Банк отправителя'),
          items: send.keys.map((k) => DropdownMenuItem(value: k, child: Text(send[k]['name']))).toList(),
          onChanged: (v) {
            AppHaptics.trigger(HapticMode.light);
            setState(() {
              routeSender = v!;
              _loadRoute();
            });
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: routeReceiver,
          decoration: InputDecoration(labelText: 'Банк получателя$psSuffix'),
          items: recv.keys.map((k) => DropdownMenuItem(value: k, child: Text('${recv[k]['name']}$psSuffix'))).toList(),
          onChanged: (v) {
            AppHaptics.trigger(HapticMode.light);
            setState(() {
              routeReceiver = v!;
              _loadRoute();
            });
          },
        ),
        const SizedBox(height: 6),
        ...['percent_fee', 'fixed_fee_azn', 'conversion_fee_percent', 'min_fee_azn', 'max_fee_azn'].map((k) => _routeField(k)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: routeMode,
          decoration: const InputDecoration(labelText: 'Способ удержания'),
          items: const [
            DropdownMenuItem(value: 'add_on', child: Text('Комиссия сверху')),
            DropdownMenuItem(value: 'deducted', child: Text('Удерживается')),
          ],
          onChanged: (v) {
            AppHaptics.trigger(HapticMode.light);
            setState(() => routeMode = v!);
          },
        ),
        const Divider(height: 24),
        ...['receiver_percent_fee', 'fixed_fee_uah', 'min_fee_uah', 'max_fee_uah'].map((k) => _routeField(k)),
        CheckboxListTile(
          value: routeVerified,
          onChanged: (v) {
            AppHaptics.trigger();
            setState(() => routeVerified = v == true);
          },
          title: Text('Тариф связки$psSuffix проверен'),
        ),
        FilledButton(
          onPressed: () {
            AppHaptics.trigger();
            _saveRoute();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Тариф связки$psSuffix сохранён')));
          },
          child: const Text('Сохранить тариф связки'),
        ),
        TextButton(
          onPressed: () {
            AppHaptics.trigger();
            data[_routesKey].remove('$routeSender->$routeReceiver');
            _loadRoute();
            setState(() {});
          },
          child: const Text('Удалить тариф связки'),
        ),
      ],
    );
  }

  Widget _routeField(String k) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: fields[k],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _tariffLabel(k, k.startsWith('receiver_') || k.endsWith('_uah')),
            hintText: k.startsWith('max_') || k.startsWith('min_') ? 'пусто = наследовать из базового тарифа' : '0',
          ),
        ),
      );

  String _tariffLabel(String key, bool receiver) {
    switch (key) {
      case 'percent_fee':
      case 'receiver_percent_fee':
        return receiver ? 'Комиссия банка получателя (%)' : 'Комиссия отправителя (%)';
      case 'fixed_fee_azn':
        return 'Фикс. комиссия отправителя (AZN)';
      case 'min_fee_azn':
        return 'Мин. комиссия отправителя (AZN)';
      case 'max_fee_azn':
        return 'Макс. комиссия отправителя (AZN)';
      case 'conversion_fee_percent':
        return 'Комиссия конвертации / буфер курса (%)';
      case 'fixed_fee_uah':
        return 'Фикс. комиссия получателя (UAH)';
      case 'min_fee_uah':
        return 'Мин. комиссия получателя (UAH)';
      case 'max_fee_uah':
        return 'Макс. комиссия получателя (UAH)';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Банки и тарифы'),
              Text(
                'Платёжная система: ${paymentSystem == 'mc' ? 'MasterCard' : 'Visa'}',
                style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppHaptics.trigger();
                _saveRoute();
                widget.onSave(data);
                Navigator.pop(c);
              },
              child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const SizedBox(width: double.infinity, child: Text('Visa', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                      selected: paymentSystem == 'visa',
                      onSelected: (_) => _switchPaymentSystem('visa'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const SizedBox(width: double.infinity, child: Text('MasterCard', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                      selected: paymentSystem == 'mc',
                      onSelected: (_) => _switchPaymentSystem('mc'),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Новые тарифы создаются неподтверждёнными. Подтверждайте их только после проверки официальных условий банка.', style: TextStyle(fontSize: 12)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in ['senders', 'receivers', 'routes'])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(t == 'senders'
                            ? 'Отправители'
                            : t == 'receivers'
                                ? 'Получатели (${paymentSystem == 'mc' ? 'MC' : 'Visa'})'
                                : 'Связки (${paymentSystem == 'mc' ? 'MC' : 'Visa'})'),
                        selected: tab == t,
                        onSelected: (_) {
                          AppHaptics.trigger(HapticMode.light);
                          setState(() => tab = t);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: tab == 'routes' ? _routeEditor() : _editBankGroup(tab)),
          ],
        ),
      );
}