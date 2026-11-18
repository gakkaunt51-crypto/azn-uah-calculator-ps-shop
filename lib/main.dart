import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart';
import 'calculator.dart';
import 'ui_extras.dart';

enum HapticMode { off, light, medium, strong }

class AppHaptics {
  static HapticMode mode = HapticMode.medium;

  static Future<void> trigger([HapticMode? override]) async {
    final m = override ?? mode;
    switch (m) {
      case HapticMode.off:
        return;
      case HapticMode.light:
        await HapticFeedback.selectionClick();
        break;
      case HapticMode.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticMode.strong:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 35));
        await HapticFeedback.vibrate();
        break;
    }
  }
}

Map<String, dynamic> defaults() {
  final kapital = senderTemplate('Kapital Bank')
    ..addAll({
      'percent_fee': '2.00',
      'fixed_fee_azn': '0.00',
      'min_fee_azn': '3.00',
      'max_fee_azn': null,
      'conversion_fee_percent': '0.50',
      'fee_mode': 'add_on',
      'verified': true,
    });
  final oshadVisa = receiverTemplate('Ощадбанк')
    ..addAll({
      'percent_fee': '1.50',
      'fixed_fee_uah': '0.00',
      'min_fee_uah': '0.00',
      'max_fee_uah': null,
      'verified': true,
    });
  final oshadMc = receiverTemplate('Ощадбанк')
    ..addAll({
      'percent_fee': '3.50',
      'fixed_fee_uah': '0.00',
      'min_fee_uah': '0.00',
      'max_fee_uah': null,
      'verified': true,
    });
  return {
    'senders': {
      'm10': senderTemplate('m10'),
      'abb': senderTemplate('ABB'),
      'kapital': kapital,
      'card_to_card': senderTemplate('Card-to-Card'),
    },
    'receivers': {
      'oshad': oshadVisa,
      'monobank': receiverTemplate('Monobank'),
      'privat': receiverTemplate('ПриватБанк'),
    },
    'routes': {
      'kapital->oshad': {
        'sender': Map<String, dynamic>.from(kapital),
        'receiver': Map<String, dynamic>.from(oshadVisa),
        'verified': true,
      },
    },
    'receivers_mc': {
      'oshad': oshadMc,
      'monobank': receiverTemplate('Monobank'),
      'privat': receiverTemplate('ПриватБанк'),
    },
    'routes_mc': {
      'kapital->oshad': {
        'sender': Map<String, dynamic>.from(kapital),
        'receiver': Map<String, dynamic>.from(oshadMc),
        'verified': true,
      },
    },
  };
}

Map<String, dynamic> senderTemplate(String name) => {
      'name': name,
      'fixed_fee_azn': '0.00',
      'percent_fee': '0.00',
      'fee_mode': 'add_on',
      'conversion_fee_percent': '0.00',
      'min_fee_azn': '0.00',
      'max_fee_azn': null,
      'verified': false,
    };

Map<String, dynamic> receiverTemplate(String name) => {
      'name': name,
      'fixed_fee_uah': '0.00',
      'percent_fee': '0.00',
      'min_fee_uah': '0.00',
      'max_fee_uah': null,
      'verified': false,
    };

void main() => runApp(const AznApp());

class AznApp extends StatefulWidget {
  const AznApp({super.key});
  @override
  State<AznApp> createState() => _AznAppState();
}

class _AznAppState extends State<AznApp> {
  String theme = 'oled-graphite';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    const legacy = {
      'Синяя': 'ocean-blue',
      'Чёрная': 'oled-graphite',
      'Светлая': 'paper-light',
      'Зелёная': 'forest',
    };
    final saved = p.getString('theme');
    final next = legacy[saved] ??
        (saved != null && appThemePalettes.any((t) => t.id == saved)
            ? saved
            : 'oled-graphite');
    if (mounted) setState(() => theme = next);
  }

  Future<void> setTheme(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', v);
    setState(() => theme = v);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemeById(theme);
    final light = palette.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AZN → UAH Calculator',
      theme: ThemeData(
        useMaterial3: true,
        brightness: light ? Brightness.light : Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.seedColor,
          brightness: light ? Brightness.light : Brightness.dark,
          surface: palette.oled ? const Color(0xFF101114) : null,
        ),
        scaffoldBackgroundColor: theme == 'oled-graphite'
            ? const Color(0xFF0E1015)
            : palette.oled
                ? const Color(0xFF08090B)
                : null,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: theme == 'oled-graphite'
              ? const Color(0xFF0E1015)
              : palette.oled
                  ? const Color(0xFF08090B)
                  : null,
          titleTextStyle: TextStyle(
            color: light ? const Color(0xFF172033) : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme == 'oled-graphite'
              ? const Color(0xFF181B22)
              : palette.oled
                  ? const Color(0xFF15171B)
                  : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: light ? const Color(0x14000000) : const Color(0x18FFFFFF),
              width: 1,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.oled ? const Color(0xFF202329) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: light ? const Color(0x18000000) : const Color(0x18FFFFFF),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: palette.seedColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            minimumSize: const Size(0, 54),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(0, 48),
          ),
        ),
      ),
      home: CalculatorPage(theme: theme, onTheme: setTheme),
    );
  }
}

enum SmartButtonStage { calculate, copyValue, copied }

class CalculatorPage extends StatefulWidget {
  final String theme;
  final Future<void> Function(String) onTheme;
  const CalculatorPage({super.key, required this.theme, required this.onTheme});
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final purchase = TextEditingController();
  final service = TextEditingController();

  Map<String, dynamic> tariffs = defaults();
  Map<String, dynamic>? quote;
  List> rateHistory = [];
  bool loading = false;
  String? error;

  String paymentSystem = 'visa'; // 'visa' | 'mc'
  String sender = 'kapital';
  String receiver = 'oshad';
  Calculation? result;
  SmartButtonStage smartStage = SmartButtonStage.calculate;
  double autoServiceFee = 100.0;

  @override
  void initState() {
    super.initState();
    purchase.addListener(_onAmountChanged);
    service.addListener(_onAmountChanged);
    _loadPrefs();
    _loadData();
    _refresh();
    Future.delayed(const Duration(minutes: 5), _periodic);
  }

  void _onAmountChanged() {
    if (result != null || smartStage != SmartButtonStage.calculate) {
      setState(() {
        result = null;
        smartStage = SmartButtonStage.calculate;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final ps = p.getString('payment_system');
    final hIdx = p.getInt('haptic_mode') ?? 2;
    final autoFee = p.getDouble('auto_service_fee') ?? 100.0;
    AppHaptics.mode = HapticMode.values[hIdx.clamp(0, HapticMode.values.length - 1)];
    if (mounted) {
      setState(() {
        if (ps == 'mc' || ps == 'visa') paymentSystem = ps!;
        autoServiceFee = autoFee;
      });
    }
  }

  Future<void> _setPaymentSystem(String system) async {
    if (paymentSystem == system) {
      AppHaptics.trigger(HapticMode.light);
      return;
    }
    AppHaptics.trigger();
    final p = await SharedPreferences.getInstance();
    await p.setString('payment_system', system);
    final recvKey = system == 'mc' ? 'receivers_mc' : 'receivers';
    final recvMap = tariffs[recvKey] as Map<String, dynamic>? ?? {};
    var nextReceiver = receiver;
    if (!recvMap.containsKey(nextReceiver)) {
      nextReceiver = recvMap.containsKey('oshad')
          ? 'oshad'
          : (recvMap.keys.isNotEmpty ? recvMap.keys.first : 'oshad');
    }
    setState(() {
      paymentSystem = system;
      receiver = nextReceiver;
      result = null;
      smartStage = SmartButtonStage.calculate;
    });
  }

  Future<void> _periodic() async {
    if (!mounted) return;
    await _refresh();
    if (mounted) Future.delayed(const Duration(minutes: 5), _periodic);
  }

  Future<Directory> _dir() async {
    final d = await getApplicationDocumentsDirectory();
    final x = Directory('${d.path}/AZN_UAH_Calculator');
    if (!await x.exists()) await x.create(recursive: true);
    return x;
  }

  void _ensureMcStructure(Map<String, dynamic> m) {
    final def = defaults();
    if (m['receivers_mc'] is! Map) {
      m['receivers_mc'] = def['receivers_mc'];
    }
    if (m['routes_mc'] is! Map) {
      m['routes_mc'] = def['routes_mc'];
    }
  }

  Future<void> _loadData() async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/tariffs.json');
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map && m['senders'] is Map && m['receivers'] is Map && m['routes'] is Map) {
          final loaded = Map<String, dynamic>.from(m);
          _ensureMcStructure(loaded);
          tariffs = loaded;
        }
      }
      final c = File('${dir.path}/exchange_cache.json');
      if (await c.exists()) quote = Map<String, dynamic>.from(jsonDecode(await c.readAsString()));
      final h = File('${dir.path}/rate_history.json');
      if (await h.exists()) {
        final raw = jsonDecode(await h.readAsString());
        if (raw is List) {
          rateHistory = raw.whereType().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final uri = Uri.parse('https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?valcode=AZN&json');
      final response = await http.get(uri, headers: {'User-Agent': 'AZN-UAH-Calculator/1.4.0'}).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final list = jsonDecode(response.body) as List;
      if (list.isEmpty) throw Exception('НБУ не вернул курс AZN');
      final item = list.first as Map;
      final rate = Decimal.parse(item['rate'].toString());
      if (rate <= Decimal.zero) throw Exception('Некорректный курс НБУ');
      quote = {
        'rate': rate.toString(),
        'source': 'Национальный банк Украины (НБУ)',
        'date': item['exchangedate']?.toString() ?? '—',
        'fetched_at': DateTime.now().toIso8601String(),
        'stale': false,
      };
      final dir = await _dir();
      await File('${dir.path}/exchange_cache.json').writeAsString(jsonEncode(quote));
      final historyFile = File('${dir.path}/rate_history.json');
      if (await historyFile.exists()) {
        final raw = jsonDecode(await historyFile.readAsString());
        if (raw is List) {
          rateHistory = raw.whereType().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      final now = DateTime.now().toIso8601String();
      if (rateHistory.isEmpty ||
          rateHistory.last['rate'].toString() != rate.toString() ||
          rateHistory.last['date'].toString() != quote!['date'].toString()) {
        rateHistory.add({
          'rate': rate.toString(),
          'date': quote!['date'],
          'recorded_at': now,
          'checked_at': now,
        });
      } else {
        rateHistory[rateHistory.length - 1]['checked_at'] = now;
      }
      await historyFile.writeAsString(const JsonEncoder.withIndent('  ').convert(rateHistory));
      error = null;
    } catch (e) {
      error = e.toString();
      if (quote != null) quote!['stale'] = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveTariffs() async {
    final dir = await _dir();
    await File('${dir.path}/tariffs.json').writeAsString(const JsonEncoder.withIndent('  ').convert(tariffs));
  }

  List<String> _orderedSenders() {
    final keys = (tariffs['senders'] as Map).keys.cast<String>().toList();
    const preferred = ['kapital', 'm10', 'abb', 'card_to_card'];
    return [...preferred.where(keys.contains), ...keys.where((k) => !preferred.contains(k))];
  }

  String get _receiversKey => paymentSystem == 'mc' ? 'receivers_mc' : 'receivers';
  String get _routesKey => paymentSystem == 'mc' ? 'routes_mc' : 'routes';

  Map<String, dynamic>? _effective() {
    final s = tariffs['senders'][sender] as Map<String, dynamic>?;
    final rMap = tariffs[_receiversKey] as Map<String, dynamic>? ?? {};
    final r = rMap[receiver] as Map<String, dynamic>?;
    if (s == null || r == null) return null;
    final routesMap = tariffs[_routesKey] as Map<String, dynamic>? ?? {};
    final route = routesMap['$sender->$receiver'];
    if (route is Map) {
      final ss = {...s, ...Map<String, dynamic>.from(route['sender'] ?? {})};
      final rr = {...r, ...Map<String, dynamic>.from(route['receiver'] ?? {})};
      for (final k in ['min_fee_azn', 'max_fee_azn']) {
        final v = route['sender']?[k];
        if ((v == null || v == '' || v == '0' || v == '0.00') && s[k] != null && s[k] != '0.00') {
          ss[k] = s[k];
        }
      }
      for (final k in ['min_fee_uah', 'max_fee_uah']) {
        final v = route['receiver']?[k];
        if ((v == null || v == '' || v == '0' || v == '0.00') && r[k] != null && r[k] != '0.00') {
          rr[k] = r[k];
        }
      }
      return {'sender': ss, 'receiver': rr, 'verified': route['verified'] == true};
    }
    if (s['verified'] == true && r['verified'] == true) {
      return {'sender': s, 'receiver': r, 'verified': true};
    }
    return null;
  }

  Future<void> _onSmartButtonPressed() async {
    AppHaptics.trigger();
    if (smartStage == SmartButtonStage.calculate) {
      await _calculate();
    } else if (smartStage == SmartButtonStage.copyValue || smartStage == SmartButtonStage.copied) {
      final x = result;
      if (x == null) return;
      await Clipboard.setData(ClipboardData(text: money(x.senderPrincipal)));
      setState(() => smartStage = SmartButtonStage.copied);
      _message('Скопировано: ${money(x.senderPrincipal)} AZN');
    }
  }

  Future<void> _calculate() async {
    try {
      if (quote == null) throw const FormatException('Сначала дождитесь получения курса НБУ.');
      if (quote!['stale'] == true) {
        final use = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Устаревший курс'),
            content: const Text('Доступен только сохранённый курс. Использовать его для ориентировочного расчёта?'),
            actions: [
              TextButton(onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(c, false); }, child: const Text('Отмена')),
              FilledButton(onPressed: () { AppHaptics.trigger(); Navigator.pop(c, true); }, child: const Text('Использовать')),
            ],
          ),
        );
        if (use != true) return;
      }
      final t = _effective();
      if (t == null || t['verified'] != true) {
        throw FormatException('Для связки (${paymentSystem == 'mc' ? 'MasterCard' : 'Visa'}) нет подтверждённого тарифа. Откройте настройки тарифов.');
      }
      final x = calculate(
        purchase.text,
        service.text,
        quote!['rate'],
        Map<String, dynamic>.from(t['sender']),
        Map<String, dynamic>.from(t['receiver']),
      );
      setState(() {
        result = x;
        smartStage = SmartButtonStage.copyValue;
      });
    } catch (e) {
      _message(e.toString());
    }
  }

  void _message(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  String money(Decimal x) => x.toStringAsFixed(2);

  String _dateTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  Decimal? _rateDelta() {
    if (rateHistory.length < 2) return null;
    final curr = Decimal.parse(rateHistory.last['rate'].toString());
    final prev = Decimal.parse(rateHistory[rateHistory.length - 2]['rate'].toString());
    final diff = curr - prev;
    return diff == Decimal.zero ? null : diff;
  }

  void _addFromMiniCalc(double calcAmount) {
    final currentPurchase = double.tryParse(purchase.text.replaceAll(',', '.').trim()) ?? 0.0;
    final currentService = double.tryParse(service.text.replaceAll(',', '.').trim()) ?? 0.0;
    final nextPurchase = currentPurchase + calcAmount;
    final nextService = currentService + autoServiceFee;
    purchase.text = nextPurchase.toStringAsFixed(2);
    service.text = nextService.toStringAsFixed(2);
  }

  Future<void> _copyCalculation() async {
    AppHaptics.trigger();
    final x = result;
    if (x == null) return;
    final t = _effective();
    final st = t?['sender'] as Map<String, dynamic>?;
    final rt = t?['receiver'] as Map<String, dynamic>?;
    final psName = paymentSystem == 'mc' ? 'MasterCard' : 'Visa';
    final text = '''Расчёт перевода AZN → UAH ($psName):
• Покупка: ${money(x.purchase)} UAH
• Услуга: ${money(x.service)} UAH
• Курс НБУ: ${x.rate}
• Буфер конвертации (${st?['conversion_fee_percent'] ?? '0'}%): учтён
• Комиссия банка получателя (${rt?['percent_fee'] ?? '0'}%): ${money(x.receiverFee)} UAH
• Введите в приложение: ${money(x.senderPrincipal)} AZN
• Комиссия банка отправителя: ${money(x.senderFee)} AZN
• Всего спишется с карты: ${money(x.total)} AZN''';
    await Clipboard.setData(ClipboardData(text: text));
    _message('Расчёт скопирован');
  }

  String _historyText() {
    if (rateHistory.isEmpty) return 'История курса НБУ пуста.';
    final rates = rateHistory.map((e) => Decimal.parse(e['rate'].toString())).toList();
    final current = quote == null ? rates.last : Decimal.parse(quote!['rate'].toString());
    final out = StringBuffer(
      'История курса НБУ (AZN → UAH):\nПериод: ${rateHistory.first['date']} — ${rateHistory.last['date']} (записей: ${rateHistory.length})\nМин: ${rates.reduce((a, b) => a < b ? a : b).toStringAsFixed(4)} UAH | Макс: ${rates.reduce((a, b) => a > b ? a : b).toStringAsFixed(4)} UAH | Текущий: ${current.toStringAsFixed(4)} UAH\n---\n',
    );
    for (var i = 0; i < rateHistory.length; i++) {
      final e = rateHistory[i];
      final r = Decimal.parse(e['rate'].toString());
      var delta = 'базовый';
      if (i > 0) {
        final prev = Decimal.parse(rateHistory[i - 1]['rate'].toString());
        final diff = r - prev;
        final pct = (diff / prev).toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100);
        delta = '${diff >= Decimal.zero ? '+' : ''}${diff.toStringAsFixed(4)} UAH (${pct.toStringAsFixed(2)}%)';
      }
      out.writeln('${i + 1}. ${e['date']} (фиксация ${_dateTime(e['recorded_at'])}) — ${r.toStringAsFixed(4)} UAH ($delta)');
    }
    return out.toString();
  }

  Future<void> _showRateHistory() async {
    AppHaptics.trigger(HapticMode.light);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF181B22),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Expanded(child: Text('История курса НБУ', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(ctx); }, icon: const Icon(Icons.close, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: rateHistory.isEmpty
                    ? const Center(child: Text('История пока пуста', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: rateHistory.length,
                        itemBuilder: (c, index) {
                          final i = rateHistory.length - 1 - index;
                          final e = rateHistory[i];
                          final r = Decimal.parse(e['rate'].toString());
                          Decimal? diff;
                          if (i > 0) diff = r - Decimal.parse(rateHistory[i - 1]['rate'].toString());
                          final color = diff == null
                              ? Colors.white70
                              : diff > Decimal.zero
                                  ? const Color(0xFF4ADE80)
                                  : diff < Decimal.zero
                                      ? const Color(0xFFF87171)
                                      : Colors.white70;
                          final pct = diff == null
                              ? null
                              : (diff / Decimal.parse(rateHistory[i - 1]['rate'].toString())).toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(color: const Color(0xFF222631), borderRadius: BorderRadius.circular(13)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Курс на ${e['date']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                      Text('Фиксация ${_dateTime(e['recorded_at'])}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                      Text(diff == null ? 'базовый' : '${diff >= Decimal.zero ? '+' : ''}${diff.toStringAsFixed(4)} UAH (${pct!.toStringAsFixed(2)}%)', style: TextStyle(color: color, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('${r.toStringAsFixed(4)} UAH', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          AppHaptics.trigger();
                          await Clipboard.setData(ClipboardData(text: _historyText()));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История курса скопирована')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Скопировать историю'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        AppHaptics.trigger();
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Очистить историю?'),
                            content: const Text('Все записи курса будут удалены.'),
                            actions: [
                              TextButton(onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(d, false); }, child: const Text('Отмена')),
                              FilledButton(onPressed: () { AppHaptics.trigger(); Navigator.pop(d, true); }, child: const Text('Очистить')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          rateHistory.clear();
                          final dir = await _dir();
                          await File('${dir.path}/rate_history.json').writeAsString('[]');
                          setSheet(() {});
                          if (mounted) setState(() {});
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Очистить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDetails() {
    AppHaptics.trigger(HapticMode.light);
    final x = result;
    if (x == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181B22),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Подробности расчёта', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(ctx); }, icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
            const Divider(color: Color(0xFF363D4E)),
            _detail('Платёжная система', paymentSystem == 'mc' ? 'MasterCard' : 'Visa'),
            _detail('Стоимость покупки', '${money(x.purchase)} UAH'),
            _detail('Стоимость услуги', '${money(x.service)} UAH'),
            _detail('Целевая сумма к получению', '${money(x.target)} UAH'),
            _detail('Курс AZN → UAH', x.rate.toString()),
            _detail('Комиссия конвертации', '${money(x.conversionPercent)}%'),
            _detail('Сумма после конвертации', '${money(x.receiverGross)} UAH'),
            _detail('Комиссия получателя', '${money(x.receiverFee)} UAH'),
            _detail('Сумма отправки до комиссии', '${money(x.senderPrincipal)} AZN'),
            _detail('Комиссия отправителя', '${money(x.senderFee)} AZN'),
            _detail('Фактически получит', '${money(x.received)} UAH'),
            _detail('Запас округления', '${money(x.roundingExtra)} AZN'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () { AppHaptics.trigger(HapticMode.light); Navigator.pop(ctx); },
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalcSettings() async {
    AppHaptics.trigger(HapticMode.light);
    final feeCtrl = TextEditingController(text: autoServiceFee.toStringAsFixed(autoServiceFee.truncateToDouble() == autoServiceFee ? 0 : 2));
    var selectedMode = AppHaptics.mode;
    const presets = [80.0, 100.0, 120.0, 150.0, 200.0];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF181B22),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Настройки калькулятора', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              const Text('ТАКТИЛЬНЫЙ ОТКЛИК (ВИБРО)', style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in const [
                    (HapticMode.off, 'Выкл'),
                    (HapticMode.light, 'Лёгкий'),
                    (HapticMode.medium, 'Средний'),
                    (HapticMode.strong, 'Мощный'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(entry.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          selected: selectedMode == entry.$1,
                          onSelected: (_) async {
                            selectedMode = entry.$1;
                            AppHaptics.mode = entry.$1;
                            await AppHaptics.trigger(entry.$1);
                            final p = await SharedPreferences.getInstance();
                            await p.setInt('haptic_mode', entry.$1.index);
                            setSheet(() {});
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('АВТОДОБАВЛЕНИЕ К УСЛУГЕ (UAH)', style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              const Text('Прибавляется в «Стоимость услуги» при нажатии корзинки с монетками в мини-калькуляторе.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((val) {
                  final active = (double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? -1) == val;
                  return ChoiceChip(
                    label: Text('+${val.toInt()} ₴', style: const TextStyle(fontWeight: FontWeight.w700)),
                    selected: active,
                    onSelected: (_) async {
                      AppHaptics.trigger();
                      feeCtrl.text = val.toInt().toString();
                      final p = await SharedPreferences.getInstance();
                      await p.setDouble('auto_service_fee', val);
                      if (mounted) setState(() => autoServiceFee = val);
                      setSheet(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Своя сумма автодобавления (UAH)',
                  suffixText: 'UAH',
                ),
                onChanged: (v) async {
                  final parsed = double.tryParse(v.replaceAll(',', '.').trim());
                  if (parsed != null && parsed >= 0) {
                    final p = await SharedPreferences.getInstance();
                    await p.setDouble('auto_service_fee', parsed);
                    if (mounted) setState(() => autoServiceFee = parsed);
                  }
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    AppHaptics.trigger();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Готово'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    feeCtrl.dispose();
  }

  @override
  void dispose() {
    purchase.dispose();
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 390;
    final veryNarrow = screenWidth < 350;
    final horizontalPadding = screenWidth < 360 ? 12.0 : screenWidth < 420 ? 14.0 : 18.0;
    final senders = _orderedSenders();
    final receiversMap = tariffs[_receiversKey] as Map<String, dynamic>? ?? {};
    final receivers = receiversMap.keys.cast<String>().toList();
    final scheme = Theme.of(context).colorScheme;
    final dark = widget.theme == 'oled-graphite';
    const bg = Color(0xFF0E1015), panel = Color(0xFF181B22), field = Color(0xFF222631);
    const border = Color(0xFF2A2F3D), muted = Color(0xFF9CA3AF), purple = Color(0xFF7C3AED);
    final rate = quote == null
        ? 'Курс временно недоступен'
        : '1 AZN = ${Decimal.parse(quote!['rate'].toString()).toStringAsFixed(4)} UAH';
    final delta = _rateDelta();
    final active = _effective();
    final verified = active != null && active['verified'] == true;
    final st = active?['sender'] as Map<String, dynamic>?;
    final rt = active?['receiver'] as Map<String, dynamic>?;

    String feeLabel(String key, String suffix) {
      final v = st?[key] ?? rt?[key] ?? '0';
      final n = double.tryParse(v.toString()) ?? 0;
      return '${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}$suffix';
    }

    final stale = quote != null && quote!['stale'] == true;
    final textColor = dark ? Colors.white : scheme.onSurface;

    return Scaffold(
      backgroundColor: dark ? bg : null,
      appBar: AppBar(
        backgroundColor: dark ? bg : null,
        toolbarHeight: compact ? 68 : 78,
        titleSpacing: compact ? 8 : 16,
        title: Row(
          children: [
            Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              decoration: const BoxDecoration(color: purple, shape: BoxShape.circle),
              child: const Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 25),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('AZN → UAH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 17 : 19, letterSpacing: .15, height: 1.05)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('КАЛЬКУЛЯТОР • ВЕРСИЯ 1.4.0', style: TextStyle(color: muted, fontSize: compact ? 8.5 : 10, fontWeight: FontWeight.w700, letterSpacing: compact ? .55 : 1.1, height: 1.1)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: compact ? 8 : 12),
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF252A36) : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? const Color(0xFF363D4E) : scheme.outlineVariant),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.settings_rounded, color: const Color(0xFFE5E7EB), size: compact ? 23 : 27),
                onOpened: () => AppHaptics.trigger(HapticMode.light),
                onSelected: (v) {
                  AppHaptics.trigger();
                  if (v == 'theme') {
                    _showThemePicker();
                  } else if (v == 'calc_settings') {
                    _showCalcSettings();
                  } else {
                    _menu(v);
                  }
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'tariffs', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.account_balance_outlined), title: Text('Банки и тарифы'))),
                  PopupMenuItem(value: 'calc_settings', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.tune_rounded), title: Text('Настройки калькулятора'))),
                  PopupMenuItem(value: 'theme', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.palette_outlined), title: Text('Тема оформления'))),
                  PopupMenuItem(value: 'export', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.ios_share_rounded), title: Text('Экспорт настроек'))),
                  PopupMenuItem(value: 'import', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.file_upload_outlined), title: Text('Импорт настроек'))),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontalPadding, compact ? 6 : 10, horizontalPadding, compact ? 20 : 28),
              children: [
                _sectionLabel('ОБМЕННЫЙ КУРС', accent: true),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(compact ? 12 : 18),
                  decoration: BoxDecoration(
                    color: dark ? panel : scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dark ? border : scheme.outlineVariant),
                    boxShadow: dark
                        ? [
                            BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 7)),
                            BoxShadow(color: const Color(0xFF64748B).withOpacity(.035), blurRadius: 1, offset: const Offset(0, 1)),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text('Национальный банк Украины', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13)),
                                    ),
                                    if (delta != null) ...[
                                      const SizedBox(width: 6),
                                      _rateDeltaBadge(delta),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(rate, style: TextStyle(color: textColor, fontSize: veryNarrow ? 17 : compact ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: -.55, height: 1.08)),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _showRateHistory,
                            child: SizedBox(
                              width: veryNarrow ? 58 : compact ? 72 : 95,
                              height: compact ? 36 : 42,
                              child: CustomPaint(painter: RateSparklinePainter(rateHistory.map((e) => double.tryParse(e['rate'].toString()) ?? 0).toList())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: dark ? border : scheme.outlineVariant),
                      const SizedBox(height: 12),
                      if (compact) ...[
                        Row(
                          children: [
                            Icon(stale ? Icons.warning_amber_rounded : Icons.check_rounded, size: 18, color: stale ? Colors.orange : const Color(0xFF4ADE80)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(quote == null ? (error ?? 'Получаем актуальные данные…') : 'Курс на ${quote!['date']}', style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _pillButton(Icons.schedule_rounded, 'История', _showRateHistory, dark),
                            const SizedBox(width: 6),
                            _pillButton(Icons.refresh_rounded, 'Обновить', loading ? null : () { AppHaptics.trigger(); _refresh(); }, dark),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(stale ? Icons.warning_amber_rounded : Icons.check_rounded, size: 18, color: stale ? Colors.orange : const Color(0xFF4ADE80)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(quote == null ? (error ?? 'Получаем актуальные данные…') : 'Курс на ${quote!['date']}', style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12))),
                            _pillButton(Icons.schedule_rounded, 'История', _showRateHistory, dark),
                            const SizedBox(width: 6),
                            _pillButton(Icons.refresh_rounded, 'Обновить', loading ? null : () { AppHaptics.trigger(); _refresh(); }, dark),
                          ],
                        ),
                      if (error != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Не удалось обновить курс: $error', style: const TextStyle(color: Colors.orange, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 17 : 22),
                // Строка: ПАРАМЕТРЫ / ПЕРЕВОДА — [MasterCard] — [Visa] — [Калькулятор]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sectionLabel('ПАРАМЕТРЫ'),
                        const SizedBox(height: 2),
                        _sectionLabel('ПЕРЕВОДА'),
                      ],
                    ),
                    const Spacer(),
                    _paymentSystemCard(isMasterCard: true, selected: paymentSystem == 'mc', compact: compact),
                    const Spacer(),
                    _paymentSystemCard(isMasterCard: false, selected: paymentSystem == 'visa', compact: compact),
                    const Spacer(),
                    _miniCalcButton(dark, compact),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  decoration: BoxDecoration(
                    color: dark ? panel : scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dark ? border : scheme.outlineVariant),
                    boxShadow: dark ? [BoxShadow(color: Colors.black.withOpacity(.24), blurRadius: 20, offset: const Offset(0, 8))] : [],
                  ),
                  child: Column(
                    children: [
                      _amountField('Сумма покупки', 'UAH', purchase, const Color(0xFF2563EB), const Color(0xFF1D4ED8)),
                      const SizedBox(height: 10),
                      _amountField('Стоимость услуги', 'UAH', service, const Color(0xFF16A34A), const Color(0xFF15803D)),
                      SizedBox(height: compact ? 10 : 14),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: compact ? 5 : 8),
                        decoration: BoxDecoration(
                          color: dark ? field : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: dark ? const Color(0xFF323846) : scheme.outlineVariant),
                          boxShadow: dark ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 7, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _bankDrop('🇦🇿', senders, sender, (v) => setState(() { sender = v; result = null; smartStage = SmartButtonStage.calculate; }), tariffs['senders'])),
                            Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8), child: Icon(Icons.arrow_forward_rounded, color: muted, size: compact ? 17 : 24)),
                            Expanded(child: _bankDrop('🇺🇦', receivers, receiver, (v) => setState(() { receiver = v; result = null; smartStage = SmartButtonStage.calculate; }), receiversMap)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 7,
                        alignment: WrapAlignment.start,
                        children: [
                          _feeChip('${feeLabel('percent_fee', '%')} / мин ${feeLabel('min_fee_azn', ' AZN')}', dark),
                          _feeChip('Буфер ${feeLabel('conversion_fee_percent', '%')}', dark),
                          _feeChip('${paymentSystem == 'mc' ? 'MC' : 'Visa'} ${((double.tryParse(rt?['percent_fee']?.toString() ?? '0') ?? 0).toStringAsFixed(1))}%', dark),
                          OutlinedButton(
                            onPressed: () {
                              AppHaptics.trigger();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TariffPage(
                                    data: tariffs,
                                    initialPaymentSystem: paymentSystem,
                                    onSave: (v) async {
                                      tariffs = v;
                                      await _saveTariffs();
                                      setState(() {
                                        result = null;
                                        smartStage = SmartButtonStage.calculate;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4ADE80),
                              side: const BorderSide(color: Color(0xFF22C55E)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text('Настроить', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSmartButton(compact),
                      if (!verified)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text('Для расчёта (${paymentSystem == 'mc' ? 'MasterCard' : 'Visa'}) необходим подтверждённый тариф выбранной связки', style: const TextStyle(color: muted, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 22),
                  Container(
                    padding: EdgeInsets.all(compact ? 13 : 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF184E77), Color(0xFF141B29)]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF3B82B8), width: 1.15),
                      boxShadow: const [
                        BoxShadow(color: Color(0x332D9CDB), blurRadius: 22, spreadRadius: 1, offset: Offset(0, 5)),
                        BoxShadow(color: Color(0x2214B8A6), blurRadius: 12, spreadRadius: -3, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text('ВВЕДИТЕ В ПРИЛОЖЕНИЕ (${paymentSystem == 'mc' ? 'MASTERCARD' : 'VISA'})', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        FittedBox(child: Text('${money(result!.senderPrincipal)} AZN', style: TextStyle(color: Colors.white, fontSize: veryNarrow ? 25 : compact ? 28 : 32, fontWeight: FontWeight.w900, letterSpacing: .15, height: 1.05))),
                        const SizedBox(height: 16),
                        if (veryNarrow)
                          Column(
                            children: [
                              Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Всего спишется', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${money(result!.total)} AZN', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))]))]),
                              const SizedBox(height: 8),
                              Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Комиссия банка', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${money(result!.senderFee)} AZN', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))]))]),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Всего спишется', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${money(result!.total)} AZN', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))])),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Комиссия банка', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text('${money(result!.senderFee)} AZN', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))])),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (veryNarrow)
                          Column(
                            children: [
                              SizedBox(width: double.infinity, child: _resultAction(Icons.copy_rounded, 'Скопировать расчёт', _copyCalculation)),
                              const SizedBox(height: 7),
                              SizedBox(width: double.infinity, child: _resultAction(Icons.info_outline_rounded, 'Подробности', _showResultDetails)),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(child: _resultAction(Icons.copy_rounded, 'Скопировать расчёт', _copyCalculation)),
                              const SizedBox(width: 8),
                              Expanded(child: _resultAction(Icons.info_outline_rounded, 'Подробности', _showResultDetails)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text('Курс НБУ носит справочный характер и может отличаться от курса банка. Приложение не инициирует переводы и не подключается к банковским счетам.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant.withOpacity(.72), height: 1.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rateDeltaBadge(Decimal delta) {
    final up = delta > Decimal.zero;
    final bg = up ? const Color(0x2222C55E) : const Color(0x22EF4444);
    final fg = up ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    final sign = up ? '▲ +' : '▼ ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withOpacity(.45), width: .8)),
      child: Text('$sign${delta.toStringAsFixed(4)}', style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _paymentSystemCard({required bool isMasterCard, required bool selected, required bool compact}) {
    final width = compact ? 50.0 : 58.0;
    const height = 31.0; // строго равно высоте двухстрочного заголовка ПАРАМЕТРЫ / ПЕРЕВОДА
    return GestureDetector(
      onTap: () => _setPaymentSystem(isMasterCard ? 'mc' : 'visa'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDE047), Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x66FBBF24),
            width: selected ? 1.8 : 0.8,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0x88F59E0B), blurRadius: 10, spreadRadius: 1),
                ]
              : [
                  BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 4, offset: const Offset(0, 2)),
                ],
        ),
        child: Opacity(
          opacity: selected ? 1.0 : 0.58,
          child: CustomPaint(painter: PaymentCardPainter(isMasterCard: isMasterCard)),
        ),
      ),
    );
  }

  Widget _miniCalcButton(bool dark, bool compact) {
    return OutlinedButton(
      onPressed: () {
        AppHaptics.trigger();
        showDialog(
          context: context,
          builder: (_) => MiniCalcDialog(
            autoServiceFee: autoServiceFee,
            onAddToPurchase: _addFromMiniCalc,
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? const Color(0xFF252A36) : null,
        foregroundColor: dark ? Colors.white : null,
        side: BorderSide(color: dark ? const Color(0xFF363D4E) : Theme.of(context).colorScheme.outlineVariant),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: 4),
        minimumSize: const Size(0, 32),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16, height: 18, child: CustomPaint(painter: IphoneCalcIconPainter())),
          const SizedBox(width: 6),
          Text('Калькулятор', style: TextStyle(fontSize: compact ? 11.5 : 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSmartButton(bool compact) {
    late final List<Color> colors;
    late final Color shadowColor;
    late final IconData icon;
    late final String label;

    switch (smartStage) {
      case SmartButtonStage.calculate:
        colors = const [Color(0xFF6366F1), Color(0xFF7C3AED)];
        shadowColor = const Color(0x557C3AED);
        icon = Icons.calculate_rounded;
        label = 'Рассчитать перевод';
        break;
      case SmartButtonStage.copyValue:
        colors = const [Color(0xFF0284C7), Color(0xFF2563EB)];
        shadowColor = const Color(0x552563EB);
        icon = Icons.copy_rounded;
        label = 'Скопировать значение (${money(result!.senderPrincipal)} AZN)';
        break;
      case SmartButtonStage.copied:
        colors = const [Color(0xFF16A34A), Color(0xFF15803D)];
        shadowColor = const Color(0x5516A34A);
        icon = Icons.check_circle_rounded;
        label = 'Скопировано';
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: compact ? 46 : 48,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: colors),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: FilledButton.icon(
          onPressed: _onSmartButtonPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          icon: Icon(icon, size: 19, color: Colors.white),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(IconData icon, String label, VoidCallback? action, bool dark) => OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 16, color: const Color(0xFFA78BFA)),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF252A36) : null,
          foregroundColor: dark ? Colors.white : null,
          side: BorderSide(color: dark ? const Color(0xFF363D4E) : Theme.of(context).colorScheme.outlineVariant),
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 390 ? 7 : 10, vertical: 4),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _amountField(String label, String currency, TextEditingController controller, Color a, Color b) {
    final dark = widget.theme == 'oled-graphite';
    final tiny = MediaQuery.sizeOf(context).width < 350;
    final artwork = label.toLowerCase().contains('покуп') ? AmountArtwork.shopping : AmountArtwork.wallet;
    final hasText = controller.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(tiny ? 6 : 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF222631) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? const Color(0xFF323846) : Theme.of(context).colorScheme.outlineVariant),
        boxShadow: dark ? [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 8, offset: const Offset(0, 3))] : [],
      ),
      child: Row(
        children: [
          Container(
            width: tiny ? 44 : 54,
            height: tiny ? 44 : 54,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [a, b]), borderRadius: BorderRadius.circular(13)),
            child: CustomPaint(painter: FintechAmountPainter(artwork)),
          ),
          SizedBox(width: tiny ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFFB7BEC9), fontSize: 12, fontWeight: FontWeight.w500)),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: tiny ? 18 : 20, fontWeight: FontWeight.w800, letterSpacing: .15),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(.35)),
                    suffixText: currency,
                    suffixStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          if (hasText)
            IconButton(
              tooltip: 'Очистить поле',
              onPressed: () {
                AppHaptics.trigger(HapticMode.light);
                controller.clear();
              },
              icon: const Icon(Icons.cleaning_services_rounded, size: 19, color: Color(0xFF9CA3AF)),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _bankDrop(String flag, List<String> keys, String selected, ValueChanged<String> onChanged, Map banks) {
    final isAzerbaijan = flag.contains('🇦🇿');
    final tiny = MediaQuery.sizeOf(context).width < 350;
    final currentName = (banks[selected] is Map ? banks[selected]['name'] : null)?.toString() ?? selected;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        AppHaptics.trigger(HapticMode.light);
        final chosen = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF181B22),
          useSafeArea: true,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Выберите банк', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: keys.map((k) {
                      final name = (banks[k] is Map ? banks[k]['name'] : null)?.toString() ?? k;
                      final country = _flagForBank(k, name, isAzerbaijan);
                      return ListTile(
                        leading: SizedBox(width: tiny ? 27 : 32, height: tiny ? 18 : 22, child: CustomPaint(painter: CountryFlagPainter(country))),
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                        trailing: k == selected ? const Icon(Icons.check_circle, color: Color(0xFF4ADE80)) : null,
                        onTap: () {
                          AppHaptics.trigger();
                          Navigator.pop(ctx, k);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
        if (chosen != null) onChanged(chosen);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(currentName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: tiny ? 11 : 13, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            SizedBox(width: tiny ? 20 : 24, height: tiny ? 14 : 16, child: CustomPaint(painter: CountryFlagPainter(_flagForBank(selected, currentName, isAzerbaijan)))),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  String _flagForBank(String key, String name, bool defaultAzerbaijan) {
    final v = '$key $name'.toLowerCase();
    if (v.contains('oshad') || v.contains('ощад') || v.contains('mono') || v.contains('приват') || v.contains('ukraine') || v.contains('укра')) return 'ua';
    if (v.contains('kapital') || v.contains('m10') || v.contains('abb') || v.contains('azer') || v.contains('азер')) return 'az';
    return defaultAzerbaijan ? 'az' : 'ua';
  }

  Widget _feeChip(String text, bool dark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF222631) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? const Color(0xFF303746) : Theme.of(context).colorScheme.outlineVariant.withOpacity(.5)),
        ),
        child: Text(text, style: TextStyle(color: dark ? const Color(0xFFD1D5DB) : Theme.of(context).colorScheme.onSurface, fontSize: 11)),
      );

  Widget _resultAction(IconData icon, String label, VoidCallback action) => OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 18, color: const Color(0xFF93C5FD)),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF171C26),
          side: const BorderSide(color: Color(0xFF4B5563)),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          elevation: 0,
        ),
      );

  Widget _sectionLabel(String text, {bool accent = false}) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.25,
          height: 1.15,
          color: accent && widget.theme == 'oled-graphite' ? const Color(0xFFA5B4FC) : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _detail(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(a)), Text(b, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );

  void _showThemePicker() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .84,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Темы оформления', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('50 вариантов · 30 с градиентами', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.palette_outlined, color: scheme.primary, size: 24),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.58),
                itemCount: appThemePalettes.length,
                itemBuilder: (context, index) {
                  final option = appThemePalettes[index];
                  final selected = widget.theme == option.id;
                  return Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        AppHaptics.trigger();
                        await widget.onTheme(option.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(color: option.isGradient ? null : option.seedColor, gradient: option.gradient, borderRadius: BorderRadius.circular(11)),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: selected ? Icon(Icons.check_circle_rounded, color: option.isGradient ? Colors.white : scheme.onPrimary, size: 17) : const SizedBox(width: 17, height: 17),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Expanded(child: Text(option.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                if (option.isGradient) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.gradient_rounded, size: 14, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(String v) async {
    if (v == 'tariffs') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TariffPage(
            data: tariffs,
            initialPaymentSystem: paymentSystem,
            onSave: (x) async {
              tariffs = x;
              await _saveTariffs();
              setState(() {
                result = null;
                smartStage = SmartButtonStage.calculate;
              });
            },
          ),
        ),
      );
    } else if (v == 'export') {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/AZN_UAH_Calculator_settings.json');
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert({...tariffs, 'rate_history': rateHistory}));
      await Share.shareXFiles([XFile(f.path)], text: 'AZN → UAH Calculator settings');
    } else if (v == 'import') {
      try {
        final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
        if (picked == null) return;
        final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
        final m = jsonDecode(utf8.decode(bytes));
        if (m is! Map || m['senders'] is! Map || m['receivers'] is! Map || m['routes'] is! Map) {
          throw const FormatException('Файл должен содержать разделы senders, receivers и routes.');
        }
        final imported = Map<String, dynamic>.from(m);
        _ensureMcStructure(imported);
        if (imported['rate_history'] is List) {
          rateHistory = (imported['rate_history'] as List).whereType().map((e) => Map<String, dynamic>.from(e)).toList();
          final dir = await _dir();
          await File('${dir.path}/rate_history.json').writeAsString(const JsonEncoder.withIndent('  ').convert(rateHistory));
        }
        imported.remove('rate_history');
        setState(() {
          tariffs = imported;
          result = null;
          smartStage = SmartButtonStage.calculate;
        });
        await _saveTariffs();
        _message('Настройки импортированы.');
      } catch (e) {
        _message('Ошибка импорта: $e');
      }
    }
  }
}