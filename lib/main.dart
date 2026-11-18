import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

enum HapticIntensity { off, light, medium, heavy }

HapticIntensity _currentHapticIntensity = HapticIntensity.medium;

void _triggerHaptic({HapticIntensity? override, bool accent = false}) {
  final level = override ?? _currentHapticIntensity;
  if (level == HapticIntensity.off) return;
  switch (level) {
    case HapticIntensity.off:
      return;
    case HapticIntensity.light:
      HapticFeedback.selectionClick();
      break;
    case HapticIntensity.medium:
      if (accent) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      break;
    case HapticIntensity.heavy:
      HapticFeedback.heavyImpact();
      break;
  }
}

Map<String, dynamic> _defaultMcReceivers() {
  final oshadMc = _receiver('Ощадбанк')
    ..addAll({
      'percent_fee': '3.50',
      'fixed_fee_uah': '0.00',
      'min_fee_uah': '0.00',
      'max_fee_uah': null,
      'verified': true,
    });
  return {
    'oshad': oshadMc,
    'monobank': _receiver('Monobank'),
    'privat': _receiver('ПриватБанк'),
  };
}

Map<String, dynamic> _defaultMcRoutes(Map<String, dynamic> kapital, Map<String, dynamic> oshadMc) {
  return {
    'kapital->oshad': {
      'sender': Map<String, dynamic>.from(kapital),
      'receiver': Map<String, dynamic>.from(oshadMc),
      'verified': true,
    },
  };
}

Map<String, dynamic> defaults() {
  final kapital = _sender('Kapital Bank')
    ..addAll({
      'percent_fee': '2.00',
      'fixed_fee_azn': '0.00',
      'min_fee_azn': '3.00',
      'max_fee_azn': null,
      'conversion_fee_percent': '0.50',
      'fee_mode': 'add_on',
      'verified': true,
    });
  final oshad = _receiver('Ощадбанк')
    ..addAll({
      'percent_fee': '1.50',
      'fixed_fee_uah': '0.00',
      'min_fee_uah': '0.00',
      'max_fee_uah': null,
      'verified': true,
    });
  final mcReceivers = _defaultMcReceivers();
  return {
    'senders': {
      'm10': _sender('m10'),
      'abb': _sender('ABB'),
      'kapital': kapital,
      'card_to_card': _sender('Card-to-Card'),
    },
    'receivers': {
      'oshad': oshad,
      'monobank': _receiver('Monobank'),
      'privat': _receiver('ПриватБанк'),
    },
    'routes': {
      'kapital->oshad': {
        'sender': Map<String, dynamic>.from(kapital),
        'receiver': Map<String, dynamic>.from(oshad),
        'verified': true,
      },
    },
    'mc_receivers': mcReceivers,
    'mc_routes': _defaultMcRoutes(kapital, Map<String, dynamic>.from(mcReceivers['oshad'])),
  };
}

Map<String, dynamic> _sender(String name) => {
  'name': name,
  'fixed_fee_azn': '0.00',
  'percent_fee': '0.00',
  'fee_mode': 'add_on',
  'conversion_fee_percent': '0.00',
  'min_fee_azn': '0.00',
  'max_fee_azn': null,
  'verified': false,
};

Map<String, dynamic> _receiver(String name) => {
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
        (saved != null && appThemePalettes.any((t) => t.id == saved) ? saved : 'oled-graphite');
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

enum _PrimaryBtnStage { calculate, readyToCopy, copied }

enum CardNetwork { mastercard, visa }

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
  String sender = 'kapital';
  String receiver = 'oshad';
  Calculation? result;

  _PrimaryBtnStage _btnStage = _PrimaryBtnStage.calculate;
  bool _purchaseHasInput = false;
  bool _serviceHasInput = false;
  Decimal _serviceStepUah = Decimal.fromInt(100);
  HapticIntensity _hapticIntensity = HapticIntensity.medium;
  CardNetwork _cardNetwork = CardNetwork.visa;

  @override
  void initState() {
    super.initState();
    purchase.addListener(_onFieldsChanged);
    service.addListener(_onFieldsChanged);
    _loadPrefs();
    _loadData();
    _refresh();
    Future.delayed(const Duration(minutes: 5), _periodic);
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final savedStep = p.getString('calc_service_step_uah');
    if (savedStep != null) {
      final parsed = Decimal.tryParse(savedStep.replaceAll(',', '.').trim());
      if (parsed != null && parsed >= Decimal.zero && mounted) {
        setState(() => _serviceStepUah = parsed);
      }
    }
    final savedHaptic = p.getString('calc_haptic_intensity');
    if (savedHaptic != null) {
      final match = HapticIntensity.values.where((e) => e.name == savedHaptic);
      if (match.isNotEmpty) {
        _currentHapticIntensity = match.first;
        if (mounted) setState(() => _hapticIntensity = match.first);
      }
    }
    final savedCard = p.getString('calc_card_network');
    if (savedCard != null) {
      final match = CardNetwork.values.where((e) => e.name == savedCard);
      if (match.isNotEmpty && mounted) {
        setState(() => _cardNetwork = match.first);
      }
    }
  }

  Future<void> _saveServiceStep(Decimal value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('calc_service_step_uah', _formatDecimalInput(value));
    if (mounted) {
      setState(() => _serviceStepUah = value);
    }
  }

  Future<void> _saveHapticIntensity(HapticIntensity value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('calc_haptic_intensity', value.name);
    _currentHapticIntensity = value;
    if (mounted) {
      setState(() => _hapticIntensity = value);
    }
  }

  Future<void> _selectCardNetwork(CardNetwork network) async {
    if (_cardNetwork == network) {
      _triggerHaptic();
      return;
    }
    _triggerHaptic(accent: true);
    final p = await SharedPreferences.getInstance();
    await p.setString('calc_card_network', network.name);
    if (!mounted) return;
    setState(() {
      _cardNetwork = network;
      final activeReceivers = _activeReceiversMap();
      if (!activeReceivers.containsKey(receiver) && activeReceivers.isNotEmpty) {
        receiver = activeReceivers.keys.first;
      }
      result = null;
      _btnStage = _PrimaryBtnStage.calculate;
    });
  }

  void _ensureMcTariffSections(Map<String, dynamic> data) {
    final baseReceivers = data['receivers'] as Map<String, dynamic>;
    if (data['mc_receivers'] is! Map) {
      final mcMap = <String, dynamic>{};
      final defaultMc = _defaultMcReceivers();
      for (final entry in baseReceivers.entries) {
        final k = entry.key;
        final src = Map<String, dynamic>.from(entry.value as Map);
        if (defaultMc.containsKey(k)) {
          mcMap[k] = Map<String, dynamic>.from(defaultMc[k]);
        } else {
          mcMap[k] = src;
        }
      }
      data['mc_receivers'] = mcMap;
    } else {
      final mcMap = Map<String, dynamic>.from(data['mc_receivers'] as Map);
      for (final entry in baseReceivers.entries) {
        if (!mcMap.containsKey(entry.key)) {
          mcMap[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
      }
      data['mc_receivers'] = mcMap;
    }

    if (data['mc_routes'] is! Map) {
      final kapital = data['senders']?['kapital'];
      final oshadMc = data['mc_receivers']?['oshad'];
      if (kapital is Map && oshadMc is Map) {
        data['mc_routes'] = _defaultMcRoutes(
          Map<String, dynamic>.from(kapital),
          Map<String, dynamic>.from(oshadMc),
        );
      } else {
        data['mc_routes'] = <String, dynamic>{};
      }
    }
  }

  Map<String, dynamic> _activeReceiversMap() {
    _ensureMcTariffSections(tariffs);
    final key = _cardNetwork == CardNetwork.mastercard ? 'mc_receivers' : 'receivers';
    return tariffs[key] as Map<String, dynamic>;
  }

  Map<String, dynamic> _activeRoutesMap() {
    _ensureMcTariffSections(tariffs);
    final key = _cardNetwork == CardNetwork.mastercard ? 'mc_routes' : 'routes';
    return tariffs[key] as Map<String, dynamic>;
  }

  bool _fieldNotEmpty(TextEditingController c) {
    final t = c.text.replaceAll(',', '.').trim();
    if (t.isEmpty) return false;
    final v = double.tryParse(t);
    return v == null ? true : v > 0;
  }

  void _onFieldsChanged() {
    final pActive = _fieldNotEmpty(purchase);
    final sActive = _fieldNotEmpty(service);
    final needReset = _btnStage != _PrimaryBtnStage.calculate || result != null;
    if (pActive != _purchaseHasInput || sActive != _serviceHasInput || needReset) {
      if (!mounted) return;
      setState(() {
        _purchaseHasInput = pActive;
        _serviceHasInput = sActive;
        result = null;
        _btnStage = _PrimaryBtnStage.calculate;
      });
    }
  }

  void _resetFieldToZero(TextEditingController controller) {
    if (!_fieldNotEmpty(controller) && controller.text.isEmpty) return;
    _triggerHaptic(accent: true);
    setState(() {
      controller.clear();
      _purchaseHasInput = _fieldNotEmpty(purchase);
      _serviceHasInput = _fieldNotEmpty(service);
      result = null;
      _btnStage = _PrimaryBtnStage.calculate;
    });
  }

  String _formatDecimalInput(Decimal d) {
    if (d == d.truncate()) return d.toBigInt().toString();
    return d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _addFromMiniCalc(double amount) {
    final addPurchase = Decimal.tryParse(amount.toStringAsFixed(2)) ?? Decimal.zero;
    if (addPurchase <= Decimal.zero) return;

    final curPurchase = Decimal.tryParse(purchase.text.replaceAll(',', '.').trim()) ?? Decimal.zero;
    final curService = Decimal.tryParse(service.text.replaceAll(',', '.').trim()) ?? Decimal.zero;

    final nextPurchase = curPurchase + addPurchase;
    final nextService = curService + _serviceStepUah;

    setState(() {
      purchase.text = _formatDecimalInput(nextPurchase);
      service.text = _formatDecimalInput(nextService);
      _purchaseHasInput = _fieldNotEmpty(purchase);
      _serviceHasInput = _fieldNotEmpty(service);
      result = null;
      _btnStage = _PrimaryBtnStage.calculate;
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

  Future<void> _loadData() async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/tariffs.json');
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map && m['senders'] is Map && m['receivers'] is Map && m['routes'] is Map) {
          final loaded = Map<String, dynamic>.from(m);
          _ensureMcTariffSections(loaded);
          tariffs = loaded;
        }
      }
      final c = File('${dir.path}/exchange_cache.json');
      if (await c.exists()) {
        quote = Map<String, dynamic>.from(jsonDecode(await c.readAsString()));
      }
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
      final response = await http
          .get(uri, headers: {'User-Agent': 'AZN-UAH-Calculator/1.4.0'})
          .timeout(const Duration(seconds: 12));
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
    await File('${dir.path}/tariffs.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(tariffs));
  }

  List<String> _orderedSenders() {
    final keys = (tariffs['senders'] as Map).keys.cast<String>().toList();
    const preferred = ['kapital', 'm10', 'abb', 'card_to_card'];
    return [...preferred.where(keys.contains), ...keys.where((k) => !preferred.contains(k))];
  }

  Map<String, dynamic>? _effective() {
    final s = tariffs['senders'][sender] as Map<String, dynamic>?;
    final receiversMap = _activeReceiversMap();
    final routesMap = _activeRoutesMap();
    final r = receiversMap[receiver] as Map<String, dynamic>?;
    if (s == null || r == null) return null;
    final route = routesMap['$sender->$receiver'];
    if (route is Map) {
      final ss = {...s, ...Map<String, dynamic>.from(route['sender'] ?? {})};
      final rr = {...r, ...Map<String, dynamic>.from(route['receiver'] ?? {})};
      for (final k in ['min_fee_azn', 'max_fee_azn']) {
        final v = route['sender']?[k];
        if ((v == null || v == '' || v == '0' || v == '0.00') &&
            s[k] != null &&
            s[k] != '0.00') {
          ss[k] = s[k];
        }
      }
      for (final k in ['min_fee_uah', 'max_fee_uah']) {
        final v = route['receiver']?[k];
        if ((v == null || v == '' || v == '0' || v == '0.00') &&
            r[k] != null &&
            r[k] != '0.00') {
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

  Future<bool> _calculate() async {
    try {
      if (quote == null) throw const FormatException('Сначала дождитесь получения курса НБУ.');
      if (quote!['stale'] == true) {
        final use = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Устаревший курс'),
            content: const Text(
              'Доступен только сохранённый курс. Использовать его для ориентировочного расчёта?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _triggerHaptic();
                  Navigator.pop(c, false);
                },
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  _triggerHaptic(accent: true);
                  Navigator.pop(c, true);
                },
                child: const Text('Использовать'),
              ),
            ],
          ),
        );
        if (use != true) return false;
      }
      final t = _effective();
      if (t == null || t['verified'] != true) {
        throw const FormatException(
          'Для выбранной связки нет подтверждённого тарифа. Откройте настройки тарифов.',
        );
      }
      final x = calculate(
        purchase.text,
        service.text,
        quote!['rate'],
        Map<String, dynamic>.from(t['sender']),
        Map<String, dynamic>.from(t['receiver']),
      );
      setState(() => result = x);
      return true;
    } catch (e) {
      _message(e.toString());
      return false;
    }
  }

  Future<void> _onPrimaryButtonPressed() async {
    if (_btnStage == _PrimaryBtnStage.calculate) {
      _triggerHaptic(accent: true);
      final ok = await _calculate();
      if (ok && mounted) {
        setState(() => _btnStage = _PrimaryBtnStage.readyToCopy);
      }
      return;
    }

    final x = result;
    if (x == null) {
      _triggerHaptic();
      setState(() => _btnStage = _PrimaryBtnStage.calculate);
      return;
    }

    final cleanAznValue = money(x.senderPrincipal);
    await Clipboard.setData(ClipboardData(text: cleanAznValue));
    _triggerHaptic(accent: true);
    if (!mounted) return;
    setState(() => _btnStage = _PrimaryBtnStage.copied);
  }

  void _message(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  String money(Decimal x) => x.toStringAsFixed(2);

  String _dateTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  Future<void> _copyCalculation() async {
    final x = result;
    if (x == null) return;
    _triggerHaptic(accent: true);
    final t = _effective();
    final st = t?['sender'] as Map<String, dynamic>?;
    final rt = t?['receiver'] as Map<String, dynamic>?;
    final cardLabel = _cardNetwork == CardNetwork.mastercard ? 'MasterCard' : 'Visa';
    final text = '''Расчёт перевода AZN → UAH ($cardLabel):
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
        final pct =
            (diff / prev).toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100);
        delta =
            '${diff >= Decimal.zero ? '+' : ''}${diff.toStringAsFixed(4)} UAH (${pct.toStringAsFixed(2)}%)';
      }
      out.writeln(
        '${i + 1}. ${e['date']} (фиксация ${_dateTime(e['recorded_at'])}) — ${r.toStringAsFixed(4)} UAH ($delta)',
      );
    }
    return out.toString();
  }

  Future<void> _showRateHistory() async {
    _triggerHaptic();
    if (!mounted) return;
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
                    const Expanded(
                      child: Text(
                        'История курса НБУ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _triggerHaptic();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rateHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'История пока пуста',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: rateHistory.length,
                        itemBuilder: (c, index) {
                          final i = rateHistory.length - 1 - index;
                          final e = rateHistory[i];
                          final r = Decimal.parse(e['rate'].toString());
                          Decimal? diff;
                          if (i > 0) {
                            diff = r - Decimal.parse(rateHistory[i - 1]['rate'].toString());
                          }
                          final color = diff == null
                              ? Colors.white70
                              : diff > Decimal.zero
                                  ? const Color(0xFF4ADE80)
                                  : diff < Decimal.zero
                                      ? const Color(0xFFF87171)
                                      : Colors.white70;
                          final pct = diff == null
                              ? null
                              : (diff / Decimal.parse(rateHistory[i - 1]['rate'].toString()))
                                      .toDecimal(scaleOnInfinitePrecision: 8) *
                                  Decimal.fromInt(100);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222631),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Курс на ${e['date']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Фиксация ${_dateTime(e['recorded_at'])}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        diff == null
                                            ? 'базовый'
                                            : '${diff >= Decimal.zero ? '+' : ''}${diff.toStringAsFixed(4)} UAH (${pct!.toStringAsFixed(2)}%)',
                                        style: TextStyle(color: color, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${r.toStringAsFixed(4)} UAH',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
                          _triggerHaptic(accent: true);
                          await Clipboard.setData(ClipboardData(text: _historyText()));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('История курса скопирована')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Скопировать историю'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        _triggerHaptic();
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Очистить историю?'),
                            content: const Text('Все записи курса будут удалены.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  _triggerHaptic();
                                  Navigator.pop(d, false);
                                },
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  _triggerHaptic(accent: true);
                                  Navigator.pop(d, true);
                                },
                                child: const Text('Очистить'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          rateHistory.clear();
                          final dir = await _dir();
                          await File('${dir.path}/rate_history.json').writeAsString('[]');
                          setSheet(() {});
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
    final x = result;
    if (x == null) return;
    _triggerHaptic();
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
                const Expanded(
                  child: Text(
                    'Подробности расчёта',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _triggerHaptic();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const Divider(color: Color(0xFF363D4E)),
            _detail(
              'Платёжная система',
              _cardNetwork == CardNetwork.mastercard ? 'MasterCard' : 'Visa',
            ),
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
                onPressed: () {
                  _triggerHaptic();
                  Navigator.pop(ctx);
                },
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalculatorSettings() {
    _triggerHaptic();
    final stepController = TextEditingController(text: _formatDecimalInput(_serviceStepUah));
    HapticIntensity selectedHaptic = _hapticIntensity;
    String? inputError;

    String hapticTitle(HapticIntensity h) {
      switch (h) {
        case HapticIntensity.off:
          return 'Выкл';
        case HapticIntensity.light:
          return 'Лёгкий';
        case HapticIntensity.medium:
          return 'Средний';
        case HapticIntensity.heavy:
          return 'Мощный';
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Настройки калькулятора',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(Icons.tune_rounded, color: Theme.of(ctx).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Тактильный отклик (вибро)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Выберите интенсивность вибрации кнопок или отключите отклик.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in HapticIntensity.values)
                        ChoiceChip(
                          label: Text(hapticTitle(mode)),
                          selected: selectedHaptic == mode,
                          onSelected: (_) {
                            setSheet(() => selectedHaptic = mode);
                            if (mode != HapticIntensity.off) {
                              _triggerHaptic(override: mode, accent: true);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Автодобавление к услуге',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сколько гривен прибавлять к «Стоимости услуги» при каждом нажатии на корзинку с монетками в мини-калькуляторе.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stepController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Сумма за 1 позицию (UAH)',
                      hintText: '100',
                      suffixText: 'UAH',
                      errorText: inputError,
                    ),
                    onChanged: (_) {
                      if (inputError != null) setSheet(() => inputError = null);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in ['80', '100', '120', '150', '200'])
                        ActionChip(
                          label: Text('+$preset UAH'),
                          onPressed: () {
                            _triggerHaptic(override: selectedHaptic);
                            setSheet(() {
                              stepController.text = preset;
                              inputError = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final raw = stepController.text.replaceAll(',', '.').trim();
                        final parsed = Decimal.tryParse(raw);
                        if (parsed == null || parsed < Decimal.zero) {
                          _triggerHaptic(override: selectedHaptic);
                          setSheet(() => inputError = 'Введите корректную сумму (0 или больше)');
                          return;
                        }
                        await _saveHapticIntensity(selectedHaptic);
                        await _saveServiceStep(parsed);
                        _triggerHaptic(accent: true);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _message(
                          'Настройки сохранены • Услуга: +${_formatDecimalInput(parsed)} UAH • Вибро: ${hapticTitle(selectedHaptic)}',
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Сохранить настройки'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => stepController.dispose());
  }

  @override
  void dispose() {
    purchase.removeListener(_onFieldsChanged);
    service.removeListener(_onFieldsChanged);
    purchase.dispose();
    service.dispose();
    super.dispose();
  }

  Decimal? _computeRateDelta() {
    if (quote == null || rateHistory.isEmpty) return null;
    final currentRate = Decimal.parse(quote!['rate'].toString());
    final lastHistRate = Decimal.parse(rateHistory.last['rate'].toString());
    if (lastHistRate != currentRate) {
      return currentRate - lastHistRate;
    }
    if (rateHistory.length >= 2) {
      final prevHistRate = Decimal.parse(rateHistory[rateHistory.length - 2]['rate'].toString());
      return currentRate - prevHistRate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 390;
    final veryNarrow = screenWidth < 350;
    final horizontalPadding = screenWidth < 360 ? 12.0 : screenWidth < 420 ? 14.0 : 18.0;
    final senders = _orderedSenders();
    final activeReceiversMap = _activeReceiversMap();
    final receivers = activeReceiversMap.keys.cast<String>().toList();
    if (!receivers.contains(receiver) && receivers.isNotEmpty) {
      receiver = receivers.first;
    }
    final scheme = Theme.of(context).colorScheme;
    final dark = widget.theme == 'oled-graphite';
    const bg = Color(0xFF0E1015);
    const panel = Color(0xFF181B22);
    const field = Color(0xFF222631);
    const border = Color(0xFF2A2F3D);
    const muted = Color(0xFF9CA3AF);
    const purple = Color(0xFF7C3AED);
    final rate = quote == null
        ? 'Курс временно недоступен'
        : '1 AZN = ${Decimal.parse(quote!['rate'].toString()).toStringAsFixed(4)} UAH';
    final rateDelta = _computeRateDelta();
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
    final headerRowHeight = compact ? 32.0 : 34.0;

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
                  Text(
                    'AZN → UAH',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 17 : 19,
                      letterSpacing: .15,
                      height: 1.05,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'КАЛЬКУЛЯТОР • ВЕРСИЯ 1.4.0',
                      style: TextStyle(
                        color: muted,
                        fontSize: compact ? 8.5 : 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: compact ? .55 : 1.1,
                        height: 1.1,
                      ),
                    ),
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
                border: Border.all(
                  color: dark ? const Color(0xFF363D4E) : scheme.outlineVariant,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.settings_rounded,
                  color: const Color(0xFFE5E7EB),
                  size: compact ? 23 : 27,
                ),
                onOpened: () => _triggerHaptic(),
                onSelected: (v) {
                  _triggerHaptic();
                  if (v == 'theme') {
                    _showThemePicker();
                  } else if (v == 'calc_settings') {
                    _showCalculatorSettings();
                  } else {
                    _menu(v);
                  }
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(
                    value: 'tariffs',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.account_balance_outlined),
                      title: Text('Банки и тарифы'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'calc_settings',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune_rounded),
                      title: Text('Настройки калькулятора'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'theme',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Тема оформления'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.ios_share_rounded),
                      title: Text('Экспорт настроек'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.file_upload_outlined),
                      title: Text('Импорт настроек'),
                    ),
                  ),
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
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                compact ? 6 : 10,
                horizontalPadding,
                compact ? 20 : 28,
              ),
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
                            BoxShadow(
                              color: Colors.black.withOpacity(.22),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                            BoxShadow(
                              color: const Color(0xFF64748B).withOpacity(.035),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
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
                                const Text(
                                  'Национальный банк Украины',
                                  style: TextStyle(color: muted, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        rate,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: veryNarrow ? 17 : compact ? 20 : 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -.55,
                                          height: 1.08,
                                        ),
                                      ),
                                      if (rateDelta != null && rateDelta != Decimal.zero) ...[
                                        const SizedBox(width: 8),
                                        _buildRateDeltaBadge(rateDelta),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _showRateHistory,
                            child: SizedBox(
                              width: veryNarrow ? 58 : compact ? 72 : 95,
                              height: compact ? 36 : 42,
                              child: CustomPaint(
                                painter: RateSparklinePainter(
                                  rateHistory
                                      .map((e) => double.tryParse(e['rate'].toString()) ?? 0)
                                      .toList(),
                                ),
                              ),
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
                            Icon(
                              stale ? Icons.warning_amber_rounded : Icons.check_rounded,
                              size: 18,
                              color: stale ? Colors.orange : const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                quote == null
                                    ? (error ?? 'Получаем актуальные данные…')
                                    : 'Курс на ${quote!['date']}',
                                style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _pillButton(Icons.schedule_rounded, 'История', _showRateHistory, dark),
                            const SizedBox(width: 6),
                            _pillButton(
                              Icons.refresh_rounded,
                              'Обновить',
                              loading
                                  ? null
                                  : () {
                                      _triggerHaptic();
                                      _refresh();
                                    },
                              dark,
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(
                              stale ? Icons.warning_amber_rounded : Icons.check_rounded,
                              size: 18,
                              color: stale ? Colors.orange : const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                quote == null
                                    ? (error ?? 'Получаем актуальные данные…')
                                    : 'Курс на ${quote!['date']}',
                                style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12),
                              ),
                            ),
                            _pillButton(Icons.schedule_rounded, 'История', _showRateHistory, dark),
                            const SizedBox(width: 6),
                            _pillButton(
                              Icons.refresh_rounded,
                              'Обновить',
                              loading
                                  ? null
                                  : () {
                                      _triggerHaptic();
                                      _refresh();
                                    },
                              dark,
                            ),
                          ],
                        ),
                      if (error != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Не удалось обновить курс: $error',
                            style: const TextStyle(color: Colors.orange, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 17 : 22),
                SizedBox(
                  height: headerRowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: headerRowHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ПАРАМЕТРЫ',
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.15,
                                height: 1.15,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'ПЕРЕВОДА',
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.15,
                                height: 1.15,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildYellowCardButton(
                        network: CardNetwork.mastercard,
                        height: headerRowHeight,
                        compact: compact,
                        veryNarrow: veryNarrow,
                      ),
                      const Spacer(),
                      _buildYellowCardButton(
                        network: CardNetwork.visa,
                        height: headerRowHeight,
                        compact: compact,
                        veryNarrow: veryNarrow,
                      ),
                      const Spacer(),
                      _buildIphoneCalcButton(
                        height: headerRowHeight,
                        compact: compact,
                        dark: dark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  decoration: BoxDecoration(
                    color: dark ? panel : scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dark ? border : scheme.outlineVariant),
                    boxShadow: dark
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(.24),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      _amountField(
                        'Сумма покупки',
                        'UAH',
                        purchase,
                        Icons.shopping_bag_rounded,
                        const Color(0xFF2563EB),
                        const Color(0xFF1D4ED8),
                        _purchaseHasInput,
                      ),
                      const SizedBox(height: 10),
                      _amountField(
                        'Стоимость услуги',
                        'UAH',
                        service,
                        Icons.account_balance_wallet_rounded,
                        const Color(0xFF16A34A),
                        const Color(0xFF15803D),
                        _serviceHasInput,
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 12,
                          vertical: compact ? 5 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: dark ? field : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dark ? const Color(0xFF323846) : scheme.outlineVariant,
                          ),
                          boxShadow: dark
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.12),
                                    blurRadius: 7,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _bankDrop(
                                '🇦🇿',
                                senders,
                                sender,
                                (v) => setState(() {
                                  sender = v;
                                  result = null;
                                  _btnStage = _PrimaryBtnStage.calculate;
                                }),
                                tariffs['senders'],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: muted,
                                size: compact ? 17 : 24,
                              ),
                            ),
                            Expanded(
                              child: _bankDrop(
                                '🇺🇦',
                                receivers,
                                receiver,
                                (v) => setState(() {
                                  receiver = v;
                                  result = null;
                                  _btnStage = _PrimaryBtnStage.calculate;
                                }),
                                activeReceiversMap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 7,
                        alignment: WrapAlignment.start,
                        children: [
                          _feeChip(
                            '${feeLabel('percent_fee', '%')} / мин ${feeLabel('min_fee_azn', ' AZN')}',
                            dark,
                          ),
                          _feeChip('Буфер ${feeLabel('conversion_fee_percent', '%')}', dark),
                          _feeChip(
                            'Банк ${((double.tryParse(rt?['percent_fee']?.toString() ?? '0') ?? 0).toStringAsFixed(1))}%',
                            dark,
                          ),
                          OutlinedButton(
                            onPressed: () {
                              _triggerHaptic();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TariffPage(
                                    data: tariffs,
                                    initialNetwork: _cardNetwork,
                                    onSave: (v) async {
                                      _ensureMcTariffSections(v);
                                      tariffs = v;
                                      await _saveTariffs();
                                      setState(() {
                                        result = null;
                                        _btnStage = _PrimaryBtnStage.calculate;
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
                      _buildSmartPrimaryButton(compact),
                      if (!verified)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            'Для расчёта (${_cardNetwork == CardNetwork.mastercard ? 'MasterCard' : 'Visa'}) необходим подтверждённый тариф выбранной связки',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 22),
                  Container(
                    padding: EdgeInsets.all(compact ? 13 : 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF184E77), Color(0xFF141B29)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF3B82B8), width: 1.15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332D9CDB),
                          blurRadius: 22,
                          spreadRadius: 1,
                          offset: Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Color(0x2214B8A6),
                          blurRadius: 12,
                          spreadRadius: -3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ВВЕДИТЕ В ПРИЛОЖЕНИЕ',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            '${money(result!.senderPrincipal)} AZN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: veryNarrow ? 25 : compact ? 28 : 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .15,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (veryNarrow)
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Всего спишется',
                                          style: TextStyle(
                                            color: Color(0xFFCBD5E1),
                                            fontSize: 11,
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${money(result!.total)} AZN',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Комиссия банка',
                                          style: TextStyle(
                                            color: Color(0xFFCBD5E1),
                                            fontSize: 11,
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${money(result!.senderFee)} AZN',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Всего спишется',
                                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${money(result!.total)} AZN',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Комиссия банка',
                                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${money(result!.senderFee)} AZN',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (veryNarrow)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: _resultAction(
                                  Icons.copy_rounded,
                                  'Скопировать расчёт',
                                  _copyCalculation,
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                width: double.infinity,
                                child: _resultAction(
                                  Icons.info_outline_rounded,
                                  'Подробности',
                                  _showResultDetails,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _resultAction(
                                  Icons.copy_rounded,
                                  'Скопировать расчёт',
                                  _copyCalculation,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _resultAction(
                                  Icons.info_outline_rounded,
                                  'Подробности',
                                  _showResultDetails,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Курс НБУ носит справочный характер и может отличаться от курса банка. Приложение не инициирует переводы и не подключается к банковским счетам.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant.withOpacity(.72),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYellowCardButton({
    required CardNetwork network,
    required double height,
    required bool compact,
    required bool veryNarrow,
  }) {
    final isSelected = _cardNetwork == network;
    final isMc = network == CardNetwork.mastercard;
    final cardWidth = veryNarrow ? 64.0 : compact ? 74.0 : 86.0;

    return Tooltip(
      message: isMc ? 'Тарифы для MasterCard' : 'Тарифы для Visa',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectCardNetwork(network),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: cardWidth,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? const [Color(0xFFFDE047), Color(0xFFF59E0B)]
                    : const [Color(0x99FDE047), Color(0x88D97706)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFFFFF) : const Color(0x55FDE047),
                width: isSelected ? 1.5 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Opacity(
              opacity: isSelected ? 1.0 : 0.62,
              child: CustomPaint(
                painter: BankCardBadgePainter(
                  network: network,
                  selected: isSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIphoneCalcButton({
    required double height,
    required bool compact,
    required bool dark,
  }) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: () {
          _triggerHaptic();
          showDialog(
            context: context,
            builder: (_) => MiniCalcDialog(
              onAddToCart: _addFromMiniCalc,
              serviceStepLabel: _formatDecimalInput(_serviceStepUah),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF252A36) : null,
          foregroundColor: dark ? Colors.white : null,
          side: BorderSide(
            color: dark ? const Color(0xFF363D4E) : Theme.of(context).colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: 0),
          minimumSize: Size(0, height),
          maximumSize: Size(double.infinity, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 18 : 20,
              height: compact ? 22 : 24,
              child: const CustomPaint(painter: IphoneCalcIconPainter()),
            ),
            const SizedBox(width: 6),
            Text(
              'Калькулятор',
              style: TextStyle(fontSize: compact ? 11.5 : 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateDeltaBadge(Decimal delta) {
    final isUp = delta > Decimal.zero;
    final color = isUp ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    final arrow = isUp ? '▲' : '▼';
    final sign = isUp ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$arrow $sign${delta.toStringAsFixed(4)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildSmartPrimaryButton(bool compact) {
    final List<Color> colors;
    final Color shadowColor;
    final String label;
    final IconData? icon;

    switch (_btnStage) {
      case _PrimaryBtnStage.calculate:
        colors = const [Color(0xFF6366F1), Color(0xFF7C3AED)];
        shadowColor = const Color(0x557C3AED);
        label = 'Рассчитать перевод';
        icon = null;
        break;
      case _PrimaryBtnStage.readyToCopy:
        colors = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
        shadowColor = const Color(0x552563EB);
        label = 'Скопировать значение';
        icon = Icons.copy_rounded;
        break;
      case _PrimaryBtnStage.copied:
        colors = const [Color(0xFF10B981), Color(0xFF059669)];
        shadowColor = const Color(0x6610B981);
        label = 'Скопировано';
        icon = Icons.check_rounded;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: compact ? 46 : 48,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: colors,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _onPrimaryButtonPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Row(
              key: ValueKey(_btnStage),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(IconData icon, String label, VoidCallback? action, bool dark) =>
      OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 16, color: const Color(0xFFA78BFA)),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF252A36) : null,
          foregroundColor: dark ? Colors.white : null,
          side: BorderSide(
            color: dark ? const Color(0xFF363D4E) : Theme.of(context).colorScheme.outlineVariant,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 390 ? 7 : 10,
            vertical: 4,
          ),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _amountField(
    String label,
    String currency,
    TextEditingController controller,
    IconData icon,
    Color a,
    Color b,
    bool hasValue,
  ) {
    final dark = widget.theme == 'oled-graphite';
    final tiny = MediaQuery.sizeOf(context).width < 350;
    final artwork =
        label.toLowerCase().contains('покуп') ? AmountArtwork.shopping : AmountArtwork.wallet;
    return Container(
      padding: EdgeInsets.all(tiny ? 6 : 8),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF222631)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? const Color(0xFF323846) : Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: tiny ? 44 : 54,
            height: tiny ? 44 : 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [a, b]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: CustomPaint(painter: FintechAmountPainter(artwork)),
          ),
          SizedBox(width: tiny ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB7BEC9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontSize: tiny ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .15,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(.35)),
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
          const SizedBox(width: 4),
          Text(
            currency,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          _buildBroomResetButton(controller, hasValue, dark, tiny),
        ],
      ),
    );
  }

  Widget _buildBroomResetButton(
    TextEditingController controller,
    bool hasValue,
    bool dark,
    bool tiny,
  ) {
    final size = tiny ? 32.0 : 36.0;
    return Tooltip(
      message: 'Сбросить до 0',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasValue ? () => _resetFieldToZero(controller) : null,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            padding: EdgeInsets.all(tiny ? 6 : 7),
            decoration: BoxDecoration(
              color: hasValue
                  ? (dark ? const Color(0xFF2B3140) : Colors.black.withOpacity(0.08))
                  : (dark ? const Color(0xFF1B1F29) : Colors.black.withOpacity(0.03)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasValue
                    ? (dark ? const Color(0xFF424A60) : Colors.black.withOpacity(0.18))
                    : (dark ? const Color(0xFF2A303E) : Colors.black.withOpacity(0.06)),
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: hasValue ? 1.0 : 0.32,
              child: const CustomPaint(painter: BroomResetPainter()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bankDrop(
    String flag,
    List<String> keys,
    String selected,
    ValueChanged<String> onChanged,
    Map banks,
  ) {
    final isAzerbaijan = flag.contains('🇦🇿');
    final tiny = MediaQuery.sizeOf(context).width < 350;
    final currentName =
        (banks[selected] is Map ? banks[selected]['name'] : null)?.toString() ?? selected;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        _triggerHaptic();
        if (!mounted) return;
        final chosen = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF181B22),
          useSafeArea: true,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,