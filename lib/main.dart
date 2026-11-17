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

Map<String, dynamic> defaults() {
  final kapital = _sender('Kapital Bank')..addAll({'percent_fee':'2.00','fixed_fee_azn':'0.00','min_fee_azn':'3.00','max_fee_azn':null,'conversion_fee_percent':'0.50','fee_mode':'add_on','verified':true});
  final oshad = _receiver('Ощадбанк')..addAll({'percent_fee':'1.50','fixed_fee_uah':'0.00','min_fee_uah':'0.00','max_fee_uah':null,'verified':true});
  return {
    'senders': {'m10': _sender('m10'), 'abb': _sender('ABB'), 'kapital': kapital, 'card_to_card': _sender('Card-to-Card')},
    'receivers': {'oshad': oshad, 'monobank': _receiver('Monobank'), 'privat': _receiver('ПриватБанк')},
    'routes': {'kapital->oshad': {'sender': Map<String,dynamic>.from(kapital), 'receiver': Map<String,dynamic>.from(oshad), 'verified': true}},
  };
}
Map<String, dynamic> _sender(String name) => {'name':name,'fixed_fee_azn':'0.00','percent_fee':'0.00','fee_mode':'add_on','conversion_fee_percent':'0.00','min_fee_azn':'0.00','max_fee_azn':null,'verified':false};
Map<String, dynamic> _receiver(String name) => {'name':name,'fixed_fee_uah':'0.00','percent_fee':'0.00','min_fee_uah':'0.00','max_fee_uah':null,'verified':false};

void main() => runApp(const AznApp());

class AznApp extends StatefulWidget { const AznApp({super.key}); @override State<AznApp> createState()=>_AznAppState(); }
class _AznAppState extends State<AznApp> {
  String theme='oled-graphite';
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    const legacy={'Синяя':'ocean-blue','Чёрная':'oled-graphite','Светлая':'paper-light','Зелёная':'forest'};
    final saved=p.getString('theme');
    final next=legacy[saved]??(saved!=null&&appThemePalettes.any((t)=>t.id==saved)?saved:'oled-graphite');
    if(mounted)setState(()=>theme=next);
  }
  Future<void> setTheme(String v) async { final p=await SharedPreferences.getInstance(); await p.setString('theme',v); setState(()=>theme=v); }
  @override Widget build(BuildContext context){
    final palette=appThemeById(theme);
    final light=palette.light;
    return MaterialApp(debugShowCheckedModeBanner:false,title:'AZN → UAH Calculator',
      theme:ThemeData(
        useMaterial3:true,
        brightness:light?Brightness.light:Brightness.dark,
        colorScheme:ColorScheme.fromSeed(
          seedColor:palette.seedColor,
          brightness:light?Brightness.light:Brightness.dark,
          surface:palette.oled?const Color(0xFF101114):null,
        ),
        scaffoldBackgroundColor:theme=='oled-graphite'?const Color(0xFF0E1015):palette.oled?const Color(0xFF08090B):null,
        appBarTheme:AppBarTheme(
          centerTitle:false, scrolledUnderElevation:0,
          backgroundColor:theme=='oled-graphite'?const Color(0xFF0E1015):palette.oled?const Color(0xFF08090B):null,
          titleTextStyle:TextStyle(color:light?const Color(0xFF172033):Colors.white,fontSize:18,fontWeight:FontWeight.w800),
        ),
        cardTheme:CardThemeData(
          elevation:0,
          margin:EdgeInsets.zero,
          color:theme=='oled-graphite'?const Color(0xFF181B22):palette.oled?const Color(0xFF15171B):null,
          shape:RoundedRectangleBorder(
            borderRadius:BorderRadius.circular(24),
            side:BorderSide(color:light?const Color(0x14000000):const Color(0x18FFFFFF),width:1),
          ),
        ),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,
          fillColor:palette.oled?const Color(0xFF202329):null,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:light?const Color(0x18000000):const Color(0x18FFFFFF))),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:palette.seedColor,width:1.5)),
          contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:18),
        ),
        filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),minimumSize:const Size(0,54),textStyle:const TextStyle(fontWeight:FontWeight.w700))),
        outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),minimumSize:const Size(0,48))),
      ),
      home: CalculatorPage(theme:theme,onTheme:setTheme));
  }
}

enum _PrimaryBtnStage { calculate, readyToCopy, copied }

class CalculatorPage extends StatefulWidget { final String theme; final Future<void> Function(String) onTheme; const CalculatorPage({super.key,required this.theme,required this.onTheme}); @override State<CalculatorPage> createState()=>_CalculatorPageState(); }
class _CalculatorPageState extends State<CalculatorPage> {
  final purchase=TextEditingController(), service=TextEditingController();
  Map<String,dynamic> tariffs=defaults(); Map<String,dynamic>? quote; List> rateHistory=[]; bool loading=false; String? error;
  String sender='kapital', receiver='oshad'; Calculation? result;
  _PrimaryBtnStage _btnStage = _PrimaryBtnStage.calculate;
  bool _purchaseHasInput = false;
  bool _serviceHasInput = false;

  @override void initState(){
    super.initState();
    purchase.addListener(_onFieldsChanged);
    service.addListener(_onFieldsChanged);
    _loadData();
    _refresh();
    Future.delayed(const Duration(minutes:5),_periodic);
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
    final needStageReset = _btnStage != _PrimaryBtnStage.calculate;
    if (pActive != _purchaseHasInput || sActive != _serviceHasInput || needStageReset) {
      if (!mounted) return;
      setState(() {
        _purchaseHasInput = pActive;
        _serviceHasInput = sActive;
        _btnStage = _PrimaryBtnStage.calculate;
      });
    }
  }

  void _resetFieldToZero(TextEditingController controller) {
    if (!_fieldNotEmpty(controller) && controller.text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      controller.clear();
      _purchaseHasInput = _fieldNotEmpty(purchase);
      _serviceHasInput = _fieldNotEmpty(service);
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
    final nextService = curService + Decimal.fromInt(100);

    setState(() {
      purchase.text = _formatDecimalInput(nextPurchase);
      service.text = _formatDecimalInput(nextService);
      _purchaseHasInput = _fieldNotEmpty(purchase);
      _serviceHasInput = _fieldNotEmpty(service);
      _btnStage = _PrimaryBtnStage.calculate;
    });
  }

  Future<void> _periodic() async { if(!mounted)return; await _refresh(); if(mounted)Future.delayed(const Duration(minutes:5),_periodic); }
  Future<Directory> _dir() async {final d=await getApplicationDocumentsDirectory();final x=Directory('${d.path}/AZN_UAH_Calculator');if(!await x.exists())await x.create(recursive:true);return x;}
  Future<void> _loadData() async {try{final dir=await _dir();final f=File('${dir.path}/tariffs.json');if(await f.exists()){final m=jsonDecode(await f.readAsString());if(m is Map&&m['senders'] is Map&&m['receivers'] is Map&&m['routes'] is Map){tariffs=Map<String,dynamic>.from(m);}} final c=File('${dir.path}/exchange_cache.json');if(await c.exists())quote=Map<String,dynamic>.from(jsonDecode(await c.readAsString()));final h=File('${dir.path}/rate_history.json');if(await h.exists()){final raw=jsonDecode(await h.readAsString());if(raw is List)rateHistory=raw.whereType().map((e)=>Map<String,dynamic>.from(e)).toList();}}catch(_){} if(mounted)setState((){});}
  Future<void> _refresh() async {if(loading)return;setState(()=>loading=true);try{final uri=Uri.parse('https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?valcode=AZN&json');final response=await http.get(uri,headers:{'User-Agent':'AZN-UAH-Calculator/1.4.0'}).timeout(const Duration(seconds:12));if(response.statusCode!=200)throw Exception('HTTP ${response.statusCode}');final list=jsonDecode(response.body) as List;if(list.isEmpty)throw Exception('НБУ не вернул курс AZN');final item=list.first as Map;final rate=Decimal.parse(item['rate'].toString());if(rate<=Decimal.zero)throw Exception('Некорректный курс НБУ');quote={'rate':rate.toString(),'source':'Национальный банк Украины (НБУ)','date':item['exchangedate']?.toString()??'—','fetched_at':DateTime.now().toIso8601String(),'stale':false};final dir=await _dir();await File('${dir.path}/exchange_cache.json').writeAsString(jsonEncode(quote));
      final historyFile=File('${dir.path}/rate_history.json');
      if(await historyFile.exists()){final raw=jsonDecode(await historyFile.readAsString());if(raw is List)rateHistory=raw.whereType().map((e)=>Map<String,dynamic>.from(e)).toList();}
      final now=DateTime.now().toIso8601String();
      if(rateHistory.isEmpty || rateHistory.last['rate'].toString()!=rate.toString() || rateHistory.last['date'].toString()!=quote!['date'].toString()){
        rateHistory.add({'rate':rate.toString(),'date':quote!['date'],'recorded_at':now,'checked_at':now});
      }else{rateHistory[rateHistory.length-1]['checked_at']=now;}
      await historyFile.writeAsString(const JsonEncoder.withIndent('  ').convert(rateHistory));
      error=null;}catch(e){error=e.toString();if(quote!=null)quote!['stale']=true;}finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _saveTariffs() async {final dir=await _dir();await File('${dir.path}/tariffs.json').writeAsString(const JsonEncoder.withIndent('  ').convert(tariffs));}
  List<String> _orderedSenders(){final keys=(tariffs['senders'] as Map).keys.cast<String>().toList();const preferred=['kapital','m10','abb','card_to_card'];return [...preferred.where(keys.contains),...keys.where((k)=>!preferred.contains(k))];}
  Map<String,dynamic>? _effective(){final s=tariffs['senders'][sender] as Map<String,dynamic>?;final r=tariffs['receivers'][receiver] as Map<String,dynamic>?;if(s==null||r==null)return null;final route=tariffs['routes']['$sender->$receiver'];if(route is Map){final ss={...s,...Map<String,dynamic>.from(route['sender']??{})};final rr={...r,...Map<String,dynamic>.from(route['receiver']??{})};for(final k in ['min_fee_azn','max_fee_azn']){final v=route['sender']?[k];if((v==null||v==''||v=='0'||v=='0.00')&&s[k]!=null&&s[k]!='0.00')ss[k]=s[k];}for(final k in ['min_fee_uah','max_fee_uah']){final v=route['receiver']?[k];if((v==null||v==''||v=='0'||v=='0.00')&&r[k]!=null&&r[k]!='0.00')rr[k]=r[k];}return {'sender':ss,'receiver':rr,'verified':route['verified']==true};}if(s['verified']==true&&r['verified']==true)return {'sender':s,'receiver':r,'verified':true};return null;}

  Future<bool> _calculate() async {
    try {
      if (quote == null) throw FormatException('Сначала дождитесь получения курса НБУ.');
      if (quote!['stale'] == true) {
        final use = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Устаревший курс'),
            content: const Text('Доступен только сохранённый курс. Использовать его для ориентировочного расчёта?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Использовать')),
            ],
          ),
        );
        if (use != true) return false;
      }
      final t = _effective();
      if (t == null || t['verified'] != true) {
        throw FormatException('Для выбранной связки нет подтверждённого тарифа. Откройте настройки тарифов.');
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
      await HapticFeedback.mediumImpact();
      final ok = await _calculate();
      if (ok && mounted) {
        setState(() => _btnStage = _PrimaryBtnStage.readyToCopy);
      }
      return;
    }

    final x = result;
    if (x == null) {
      setState(() => _btnStage = _PrimaryBtnStage.calculate);
      return;
    }

    final cleanAznValue = money(x.senderPrincipal);
    await Clipboard.setData(ClipboardData(text: cleanAznValue));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _btnStage = _PrimaryBtnStage.copied);
  }

  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  String money(Decimal x)=>x.toStringAsFixed(2);

  String _dateTime(Object? value){final parsed=DateTime.tryParse(value?.toString()??'');return parsed==null?'—':DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());}
  Future<void> _copyCalculation() async {final x=result;if(x==null)return;await HapticFeedback.lightImpact();final t=_effective();final st=t?['sender'] as Map<String,dynamic>?;final rt=t?['receiver'] as Map<String,dynamic>?;final text='''Расчёт перевода AZN → UAH:
• Покупка: ${money(x.purchase)} UAH
• Услуга: ${money(x.service)} UAH
• Курс НБУ: ${x.rate}
• Буфер конвертации (${st?['conversion_fee_percent']??'0'}%): учтён
• Комиссия банка получателя (${rt?['percent_fee']??'0'}%): ${money(x.receiverFee)} UAH
• Введите в приложение: ${money(x.senderPrincipal)} AZN
• Комиссия банка отправителя: ${money(x.senderFee)} AZN
• Всего спишется с карты: ${money(x.total)} AZN''';await Clipboard.setData(ClipboardData(text:text));_message('Расчёт скопирован');}
  String _historyText(){if(rateHistory.isEmpty)return 'История курса НБУ пуста.';final rates=rateHistory.map((e)=>Decimal.parse(e['rate'].toString())).toList();final current=quote==null?rates.last:Decimal.parse(quote!['rate'].toString());final out=StringBuffer('История курса НБУ (AZN → UAH):\nПериод: ${rateHistory.first['date']} — ${rateHistory.last['date']} (записей: ${rateHistory.length})\nМин: ${rates.reduce((a,b)=>a<b?a:b).toStringAsFixed(4)} UAH | Макс: ${rates.reduce((a,b)=>a>b?a:b).toStringAsFixed(4)} UAH | Текущий: ${current.toStringAsFixed(4)} UAH\n---\n');for(var i=0;i<rateHistory.length;i++){final e=rateHistory[i];final r=Decimal.parse(e['rate'].toString());var delta='базовый';if(i>0){final prev=Decimal.parse(rateHistory[i-1]['rate'].toString());final diff=r-prev;final pct=(diff/prev).toDecimal(scaleOnInfinitePrecision:8)*Decimal.fromInt(100);delta='${diff>=Decimal.zero?'+':''}${diff.toStringAsFixed(4)} UAH (${pct.toStringAsFixed(2)}%)';}out.writeln('${i+1}. ${e['date']} (фиксация ${_dateTime(e['recorded_at'])}) — ${r.toStringAsFixed(4)} UAH ($delta)');}return out.toString();}
  Future<void> _showRateHistory() async {await HapticFeedback.lightImpact();if(!mounted)return;await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:const Color(0xFF181B22),builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>SizedBox(height:MediaQuery.sizeOf(ctx).height*.78,child:Column(children:[Padding(padding:const EdgeInsets.all(18),child:Row(children:[const Expanded(child:Text('История курса НБУ',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close,color:Colors.white))])),Expanded(child:rateHistory.isEmpty?const Center(child:Text('История пока пуста',style:TextStyle(color:Colors.white70))):ListView.builder(padding:const EdgeInsets.all(14),itemCount:rateHistory.length,itemBuilder:(c,index){final i=rateHistory.length-1-index;final e=rateHistory[i];final r=Decimal.parse(e['rate'].toString());Decimal? diff;if(i>0)diff=r-Decimal.parse(rateHistory[i-1]['rate'].toString());final color=diff==null?Colors.white70:diff>Decimal.zero?const Color(0xFF4ADE80):diff<Decimal.zero?const Color(0xFFF87171):Colors.white70;final pct=diff==null?null:(diff/Decimal.parse(rateHistory[i-1]['rate'].toString())).toDecimal(scaleOnInfinitePrecision:8)*Decimal.fromInt(100);return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFF222631),borderRadius:BorderRadius.circular(13)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Курс на ${e['date']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),Text('Фиксация ${_dateTime(e['recorded_at'])}',style:const TextStyle(color:Colors.white60,fontSize:11)),Text(diff==null?'базовый':'${diff>=Decimal.zero?'+':''}${diff.toStringAsFixed(4)} UAH (${pct!.toStringAsFixed(2)}%)',style:TextStyle(color:color,fontSize:12))])),Text('${r.toStringAsFixed(4)} UAH',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))]));})),Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()async{await HapticFeedback.lightImpact();await Clipboard.setData(ClipboardData(text:_historyText()));if(ctx.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('История курса скопирована')));},icon:const Icon(Icons.copy),label:const Text('Скопировать историю'))),const SizedBox(width:8),OutlinedButton.icon(onPressed:()async{final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(title:const Text('Очистить историю?'),content:const Text('Все записи курса будут удалены.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Очистить'))]));if(ok==true){rateHistory.clear();final dir=await _dir();await File('${dir.path}/rate_history.json').writeAsString('[]');setSheet((){});}},icon:const Icon(Icons.delete_outline),label:const Text('Очистить'))]))]))));}
  void _showResultDetails(){final x=result;if(x==null)return;HapticFeedback.lightImpact();showModalBottomSheet<void>(context:context,useSafeArea:true,isScrollControlled:true,backgroundColor:const Color(0xFF181B22),builder:(ctx)=>Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('Подробности расчёта',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close,color:Colors.white))]),const Divider(color:Color(0xFF363D4E)),_detail('Стоимость покупки','${money(x.purchase)} UAH'),_detail('Стоимость услуги','${money(x.service)} UAH'),_detail('Целевая сумма к получению','${money(x.target)} UAH'),_detail('Курс AZN → UAH',x.rate.toString()),_detail('Комиссия конвертации','${money(x.conversionPercent)}%'),_detail('Сумма после конвертации','${money(x.receiverGross)} UAH'),_detail('Комиссия получателя','${money(x.receiverFee)} UAH'),_detail('Сумма отправки до комиссии','${money(x.senderPrincipal)} AZN'),_detail('Комиссия отправителя','${money(x.senderFee)} AZN'),_detail('Фактически получит','${money(x.received)} UAH'),_detail('Запас округления','${money(x.roundingExtra)} AZN'),const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Закрыть')))])));}

  @override void dispose(){
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

  @override Widget build(BuildContext context){
    final screenWidth=MediaQuery.sizeOf(context).width;
    final compact=screenWidth<390;
    final veryNarrow=screenWidth<350;
    final horizontalPadding=screenWidth<360?12.0:screenWidth<420?14.0:18.0;
    final senders=_orderedSenders();
    final receivers=(tariffs['receivers'] as Map).keys.cast<String>().toList();
    final scheme=Theme.of(context).colorScheme;
    final dark=widget.theme=='oled-graphite';
    const bg=Color(0xFF0E1015), panel=Color(0xFF181B22), field=Color(0xFF222631);
    const border=Color(0xFF2A2F3D), muted=Color(0xFF9CA3AF), purple=Color(0xFF7C3AED);
    final rate=quote==null?'Курс временно недоступен':'1 AZN = ${Decimal.parse(quote!['rate'].toString()).toStringAsFixed(4)} UAH';
    final rateDelta = _computeRateDelta();
    final active=_effective();
    final verified=active!=null && active['verified']==true;
    final st=active?['sender'] as Map<String,dynamic>?;
    final rt=active?['receiver'] as Map<String,dynamic>?;
    String feeLabel(String key,String suffix){
      final v=st?[key]??rt?[key]??'0';
      final n=double.tryParse(v.toString())??0;
      return '${n.toStringAsFixed(n.truncateToDouble()==n?0:2)}$suffix';
    }
    final stale=quote!=null && quote!['stale']==true;
    final textColor=dark?Colors.white:scheme.onSurface;
    return Scaffold(
      backgroundColor:dark?bg:null,
      appBar:AppBar(
        backgroundColor:dark?bg:null,
        toolbarHeight:compact?68:78,
        titleSpacing:compact?8:16,
        title:Row(children:[
          Container(width:compact?36:40,height:compact?36:40,decoration:const BoxDecoration(color:purple,shape:BoxShape.circle),child:const Icon(Icons.currency_exchange_rounded,color:Colors.white,size:25)),
          SizedBox(width:compact?8:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
            Text('AZN → UAH',style:TextStyle(fontWeight:FontWeight.w900,fontSize:compact?17:19,letterSpacing:.15,height:1.05)),
            FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text('КАЛЬКУЛЯТОР • ВЕРСИЯ 1.4.0',style:TextStyle(color:muted,fontSize:compact?8.5:10,fontWeight:FontWeight.w700,letterSpacing:compact ? .55 : 1.1,height:1.1))),
          ])),
        ]),
        actions:[Padding(padding:EdgeInsets.only(right:compact?8:12),child:Container(decoration:BoxDecoration(color:dark?const Color(0xFF252A36):scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12),border:Border.all(color:dark?const Color(0xFF363D4E):scheme.outlineVariant)),child:PopupMenuButton<String>(icon:Icon(Icons.settings_rounded,color:const Color(0xFFE5E7EB),size:compact?23:27),onSelected:(v){HapticFeedback.lightImpact();if(v=='theme'){_showThemePicker();}else{_menu(v);}},itemBuilder:(c)=>[
          const PopupMenuItem(value:'tariffs',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.account_balance_outlined),title:Text('Банки и тарифы'))),
          const PopupMenuItem(value:'theme',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.palette_outlined),title:Text('Тема оформления'))),
          const PopupMenuItem(value:'export',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.ios_share_rounded),title:Text('Экспорт настроек'))),
          const PopupMenuItem(value:'import',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.file_upload_outlined),title:Text('Импорт настроек'))),
        ])))],
      ),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:680),
        child:ListView(
          keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
          padding:EdgeInsets.fromLTRB(horizontalPadding,compact?6:10,horizontalPadding,compact?20:28),
          children:[
            _sectionLabel('ОБМЕННЫЙ КУРС',accent:true),
            const SizedBox(height:10),
            Container(padding:EdgeInsets.all(compact?12:18),decoration:BoxDecoration(color:dark?panel:scheme.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:dark?border:scheme.outlineVariant),boxShadow:dark?[BoxShadow(color:Colors.black.withOpacity(.22),blurRadius:18,offset:const Offset(0,7)),BoxShadow(color:const Color(0xFF64748B).withOpacity(.035),blurRadius:1,offset:const Offset(0,1))]:[]),child:Column(children:[
              Row(children:[
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('Национальный банк Украины',style:TextStyle(color:muted,fontSize:13)),
                  const SizedBox(height:4),
                  FittedBox(
                    fit:BoxFit.scaleDown,
                    alignment:Alignment.centerLeft,
                    child:Row(
                      mainAxisSize:MainAxisSize.min,
                      children:[
                        Text(rate,style:TextStyle(color:textColor,fontSize:veryNarrow?17:compact?20:24,fontWeight:FontWeight.w900,letterSpacing:-.55,height:1.08)),
                        if (rateDelta != null && rateDelta != Decimal.zero) ...[
                          const SizedBox(width:8),
                          _buildRateDeltaBadge(rateDelta),
                        ],
                      ],
                    ),
                  ),
                ])),
                const SizedBox(width:6),
                GestureDetector(onTap:_showRateHistory,child:SizedBox(width:veryNarrow?58:compact?72:95,height:compact?36:42,child:CustomPaint(painter:RateSparklinePainter(rateHistory.map((e)=>double.tryParse(e['rate'].toString())??0).toList())))),
              ]),
              const SizedBox(height:14),Container(height:1,color:dark?border:scheme.outlineVariant),
              const SizedBox(height:12),
              if(compact) ...[
                Row(children:[Icon(stale?Icons.warning_amber_rounded:Icons.check_rounded,size:18,color:stale?Colors.orange:const Color(0xFF4ADE80)),const SizedBox(width:6),Expanded(child:Text(quote==null?(error??'Получаем актуальные данные…'):'Курс на ${quote!['date']}',style:const TextStyle(color:Color(0xFF86EFAC),fontSize:11))) ]),
                const SizedBox(height:8),
                Row(mainAxisAlignment:MainAxisAlignment.end,children:[_pillButton(Icons.schedule_rounded,'История',_showRateHistory,dark),const SizedBox(width:6),_pillButton(Icons.refresh_rounded,'Обновить',loading?null:(){HapticFeedback.lightImpact();_refresh();},dark)]),
              ] else Row(children:[
                Icon(stale?Icons.warning_amber_rounded:Icons.check_rounded,size:18,color:stale?Colors.orange:const Color(0xFF4ADE80)),
                const SizedBox(width:6),
                Expanded(child:Text(quote==null?(error??'Получаем актуальные данные…'):'Курс на ${quote!['date']}',style:const TextStyle(color:Color(0xFF86EFAC),fontSize:12))),
                _pillButton(Icons.schedule_rounded,'История',_showRateHistory,dark),const SizedBox(width:6),_pillButton(Icons.refresh_rounded,'Обновить',loading?null:(){HapticFeedback.lightImpact();_refresh();},dark),
              ]),
              if(error!=null)Align(alignment:Alignment.centerLeft,child:Text('Не удалось обновить курс: $error',style:const TextStyle(color:Colors.orange,fontSize:11))),
            ])),
            SizedBox(height:compact?17:22),
            Row(children:[
              Flexible(child:_sectionLabel('ПАРАМЕТРЫ ПЕРЕВОДА')),const Spacer(),
              _pillButton(Icons.calculate_outlined,'Калькулятор',(){
                HapticFeedback.lightImpact();
                showDialog(
                  context:context,
                  builder:(_)=>MiniCalcDialog(onAddToCart:_addFromMiniCalc),
                );
              },dark),
            ]),
            const SizedBox(height:10),
            Container(padding:EdgeInsets.all(compact?10:16),decoration:BoxDecoration(color:dark?panel:scheme.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:dark?border:scheme.outlineVariant),boxShadow:dark?[BoxShadow(color:Colors.black.withOpacity(.24),blurRadius:20,offset:const Offset(0,8))]:[]),child:Column(children:[
              _amountField('Сумма покупки','UAH',purchase,Icons.shopping_bag_rounded,const Color(0xFF2563EB),const Color(0xFF1D4ED8),_purchaseHasInput),
              const SizedBox(height:10),
              _amountField('Стоимость услуги','UAH',service,Icons.account_balance_wallet_rounded,const Color(0xFF16A34A),const Color(0xFF15803D),_serviceHasInput),
              SizedBox(height:compact?10:14),
              Container(padding:EdgeInsets.symmetric(horizontal:compact?6:12,vertical:compact?5:8),decoration:BoxDecoration(color:dark?field:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14),border:Border.all(color:dark?const Color(0xFF323846):scheme.outlineVariant),boxShadow:dark?[BoxShadow(color:Colors.black.withOpacity(.12),blurRadius:7,offset:const Offset(0,2))]:[]),child:Row(children:[
                Expanded(child:_bankDrop('🇦🇿',senders,sender,(v)=>setState((){sender=v;_btnStage=_PrimaryBtnStage.calculate;}),tariffs['senders'])),
                Padding(padding:EdgeInsets.symmetric(horizontal:compact?2:8),child:Icon(Icons.arrow_forward_rounded,color:muted,size:compact?17:24)),
                Expanded(child:_bankDrop('🇺🇦',receivers,receiver,(v)=>setState((){receiver=v;_btnStage=_PrimaryBtnStage.calculate;}),tariffs['receivers'])),
              ])),
              const SizedBox(height:10),
              Wrap(spacing:5,runSpacing:7,alignment:WrapAlignment.start,children:[
                _feeChip('${feeLabel('percent_fee','%')} / мин ${feeLabel('min_fee_azn',' AZN')}',dark),
                _feeChip('Буфер ${feeLabel('conversion_fee_percent','%')}',dark),
                _feeChip('Банк ${((double.tryParse(rt?['percent_fee']?.toString()??'0')??0).toStringAsFixed(1))}%',dark),
                OutlinedButton(onPressed:(){HapticFeedback.lightImpact();Navigator.push(context,MaterialPageRoute(builder:(_)=>TariffPage(data:tariffs,onSave:(v)async{tariffs=v;await _saveTariffs();setState((){result=null;_btnStage=_PrimaryBtnStage.calculate;});})));},style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFF4ADE80),side:const BorderSide(color:Color(0xFF22C55E)),padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),minimumSize:const Size(0,30)),child:const Text('Настроить',style:TextStyle(fontSize:12))),
              ]),
              const SizedBox(height:12),
              _buildSmartPrimaryButton(compact),
              if(!verified)const Padding(padding:EdgeInsets.only(top:9),child:Text('Для расчёта необходим подтверждённый тариф выбранной связки',style:TextStyle(color:muted,fontSize:11))),
            ])),
            if(result!=null)...[
              const SizedBox(height:22),
              Container(padding:EdgeInsets.all(compact?13:18),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF184E77),Color(0xFF141B29)]),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF3B82B8),width:1.15),boxShadow:const [BoxShadow(color:Color(0x332D9CDB),blurRadius:22,spreadRadius:1,offset:Offset(0,5)),BoxShadow(color:Color(0x2214B8A6),blurRadius:12,spreadRadius:-3,offset:Offset(0,2))]),child:Column(children:[
                const Text('ВВЕДИТЕ В ПРИЛОЖЕНИЕ',style:TextStyle(color:Color(0xFFCBD5E1),fontSize:11,letterSpacing:1,fontWeight:FontWeight.w700)),
                const SizedBox(height:4),
                FittedBox(child:Text('${money(result!.senderPrincipal)} AZN',style:TextStyle(color:Colors.white,fontSize:veryNarrow?25:compact?28:32,fontWeight:FontWeight.w900,letterSpacing:.15,height:1.05))),
                const SizedBox(height:16),
                if(veryNarrow) Column(children:[
                  Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Всего спишется',style:TextStyle(color:Color(0xFFCBD5E1),fontSize:11)),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text('${money(result!.total)} AZN',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)))]))]),
                  const SizedBox(height:8),
                  Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Комиссия банка',style:TextStyle(color:Color(0xFFCBD5E1),fontSize:11)),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text('${money(result!.senderFee)} AZN',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)))]))]),
                ]) else Row(children:[
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Всего спишется',style:TextStyle(color:Color(0xFFCBD5E1),fontSize:12)),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text('${money(result!.total)} AZN',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)))])),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[const Text('Комиссия банка',style:TextStyle(color:Color(0xFFCBD5E1),fontSize:12)),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerRight,child:Text('${money(result!.senderFee)} AZN',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)))])),
                ]),
                const SizedBox(height:16),
                if(veryNarrow) Column(children:[SizedBox(width:double.infinity,child:_resultAction(Icons.copy_rounded,'Скопировать расчёт',_copyCalculation)),const SizedBox(height:7),SizedBox(width:double.infinity,child:_resultAction(Icons.info_outline_rounded,'Подробности',_showResultDetails))]) else Row(children:[Expanded(child:_resultAction(Icons.copy_rounded,'Скопировать расчёт',_copyCalculation)),const SizedBox(width:8),Expanded(child:_resultAction(Icons.info_outline_rounded,'Подробности',_showResultDetails))]),
              ])),
            ],
            const SizedBox(height:18),
            Text('Курс НБУ носит справочный характер и может отличаться от курса банка. Приложение не инициирует переводы и не подключается к банковским счетам.',textAlign:TextAlign.center,style:TextStyle(fontSize:10.5,color:scheme.onSurfaceVariant.withOpacity(.72),height:1.45)),
          ],
        ),
      ))),
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

  Widget _pillButton(IconData icon,String label,VoidCallback? action,bool dark)=>OutlinedButton.icon(
    onPressed:action,icon:Icon(icon,size:16,color:const Color(0xFFA78BFA)),label:Text(label,style:const TextStyle(fontSize:12)),
    style:OutlinedButton.styleFrom(backgroundColor:dark?const Color(0xFF252A36):null,foregroundColor:dark?Colors.white: null,side:BorderSide(color:dark?const Color(0xFF363D4E):Theme.of(context).colorScheme.outlineVariant),padding:EdgeInsets.symmetric(horizontal:MediaQuery.sizeOf(context).width<390?7:10,vertical:4),minimumSize:const Size(0,32),visualDensity:VisualDensity.compact),
  );

  Widget _amountField(String label,String currency,TextEditingController controller,IconData icon,Color a,Color b,bool hasValue){
    final dark=widget.theme=='oled-graphite';
    final tiny=MediaQuery.sizeOf(context).width<350;
    final artwork=label.toLowerCase().contains('покуп')?AmountArtwork.shopping:AmountArtwork.wallet;
    return Container(
      padding:EdgeInsets.all(tiny?6:8),
      decoration:BoxDecoration(color:dark?const Color(0xFF222631):Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14),border:Border.all(color:dark?const Color(0xFF323846):Theme.of(context).colorScheme.outlineVariant),boxShadow:dark?[BoxShadow(color:Colors.black.withOpacity(.14),blurRadius:8,offset:const Offset(0,3))]:[]),
      child:Row(children:[
        Container(width:tiny?44:54,height:tiny?44:54,decoration:BoxDecoration(gradient:LinearGradient(colors:[a,b]),borderRadius:BorderRadius.circular(13)),child:CustomPaint(painter:FintechAmountPainter(artwork))),
        SizedBox(width:tiny?8:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(color:Color(0xFFB7BEC9),fontSize:12,fontWeight:FontWeight.w500)),
          TextField(
            controller:controller,
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            style:TextStyle(color:dark?Colors.white:Theme.of(context).colorScheme.onSurface,fontSize:tiny?18:20,fontWeight:FontWeight.w800,letterSpacing:.15),
            decoration:InputDecoration(
              hintText:'0.00',
              hintStyle:TextStyle(color:Colors.white.withOpacity(.35)),
              border:InputBorder.none,
              enabledBorder:InputBorder.none,
              focusedBorder:InputBorder.none,
              contentPadding:EdgeInsets.zero,
              isDense:true,
            ),
          ),
        ])),
        const SizedBox(width:4),
        Text(currency,style:const TextStyle(color:Color(0xFF9CA3AF),fontSize:15,fontWeight:FontWeight.w600)),
        const SizedBox(width:8),
        _buildBroomResetButton(controller,hasValue,dark,tiny),
      ]),
    );
  }

  Widget _buildBroomResetButton(TextEditingController controller, bool hasValue, bool dark, bool tiny) {
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
              child: const CustomPaint(
                painter: BroomResetPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bankDrop(String flag,List<String> keys,String selected,ValueChanged<String> onChanged,Map banks){
    final isAzerbaijan=flag.contains('🇦🇿');
    final tiny=MediaQuery.sizeOf(context).width<350;
    final currentName=(banks[selected] is Map?banks[selected]['name']:null)?.toString()??selected;
    return InkWell(
      borderRadius:BorderRadius.circular(10),
      onTap:() async {
        await HapticFeedback.lightImpact();
        if(!mounted)return;
        final chosen=await showModalBottomSheet<String>(
          context:context,backgroundColor:const Color(0xFF181B22),useSafeArea:true,showDragHandle:true,
          builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
            const Padding(padding:EdgeInsets.fromLTRB(20,4,20,12),child:Align(alignment:Alignment.centerLeft,child:Text('Выберите банк',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)))),
            Flexible(child:ListView(shrinkWrap:true,children:keys.map((k){
              final name=(banks[k] is Map?banks[k]['name']:null)?.toString()??k;
              final country=_flagForBank(k,name,isAzerbaijan);
              return ListTile(
                leading:SizedBox(width:tiny?27:32,height:tiny?18:22,child:CustomPaint(painter:CountryFlagPainter(country))),
                title:Text(name,style:const TextStyle(color:Colors.white)),
                trailing:k==selected?const Icon(Icons.check_circle,color:Color(0xFF4ADE80)):null,
                onTap:(){HapticFeedback.lightImpact();Navigator.pop(ctx,k);},
              );
            }).toList())),
          ])),
        );
        if(chosen!=null)onChanged(chosen);
      },
      child:Padding(
        padding:const EdgeInsets.symmetric(vertical:7,horizontal:2),
        child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Flexible(child:Text(currentName,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:tiny?11:13,fontWeight:FontWeight.w600))),
          const SizedBox(width:6),
          SizedBox(width:tiny?20:24,height:tiny?14:16,child:CustomPaint(painter:CountryFlagPainter(_flagForBank(selected,currentName,isAzerbaijan)))),
          const SizedBox(width:2),
          const Icon(Icons.expand_more_rounded,size:16,color:Color(0xFF9CA3AF)),
        ]),
      ),
    );
  }

  String _flagForBank(String key,String name,bool defaultAzerbaijan){
    final v='$key $name'.toLowerCase();
    if(v.contains('oshad')||v.contains('ощад')||v.contains('mono')||v.contains('приват')||v.contains('ukraine')||v.contains('укра'))return 'ua';
    if(v.contains('kapital')||v.contains('m10')||v.contains('abb')||v.contains('azer')||v.contains('азер'))return 'az';
    return defaultAzerbaijan?'az':'ua';
  }

  Widget _feeChip(String text,bool dark)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:dark?const Color(0xFF222631):Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14),border:Border.all(color:dark?const Color(0xFF303746):Theme.of(context).colorScheme.outlineVariant.withOpacity(.5))),child:Text(text,style:TextStyle(color:dark?const Color(0xFFD1D5DB):Theme.of(context).colorScheme.onSurface,fontSize:11)));

  Widget _resultAction(IconData icon,String label,VoidCallback action)=>OutlinedButton.icon(onPressed:action,icon:Icon(icon,size:18,color:const Color(0xFF93C5FD)),label:FittedBox(fit:BoxFit.scaleDown,child:Text(label)),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,backgroundColor:const Color(0xFF171C26),side:const BorderSide(color:Color(0xFF4B5563)),shape:const StadiumBorder(),minimumSize:const Size(0,42),padding:const EdgeInsets.symmetric(horizontal:8),elevation:0));
  Widget _sectionLabel(String text,{bool accent=false})=>Text(text,style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.25,color:accent&&widget.theme=='oled-graphite'?const Color(0xFFA5B4FC):Theme.of(context).colorScheme.onSurfaceVariant));
  Widget _detail(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[Expanded(child:Text(a)),Text(b,style:const TextStyle(fontWeight:FontWeight.w600))]));
  void _showThemePicker(){
    final scheme=Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      showDragHandle:true,
      backgroundColor:scheme.surface,
      builder:(sheetContext)=>FractionallySizedBox(
        heightFactor:.84,
        child:Column(children:[
          Padding(
            padding:const EdgeInsets.fromLTRB(20,2,20,14),
            child:Row(children:[
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Темы оформления',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
                const SizedBox(height:3),
                Text('50 вариантов · 30 с градиентами',style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant)),
              ])),
              Icon(Icons.palette_outlined,color:scheme.primary,size:24),
            ]),
          ),
          Expanded(child:GridView.builder(
            padding:const EdgeInsets.fromLTRB(16,0,16,24),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.58),
            itemCount:appThemePalettes.length,
            itemBuilder:(context,index){
              final option=appThemePalettes[index];
              final selected=widget.theme==option.id;
              return Material(
                color:scheme.surfaceContainerLow,
                borderRadius:BorderRadius.circular(18),
                child:InkWell(
                  borderRadius:BorderRadius.circular(18),
                  onTap:()async{await HapticFeedback.lightImpact();await widget.onTheme(option.id);if(sheetContext.mounted)Navigator.pop(sheetContext);},
                  child:Container(
                    padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?scheme.primary:scheme.outlineVariant,width:selected?2:1)),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Expanded(child:Container(
                        width:double.infinity,
                        decoration:BoxDecoration(color:option.isGradient?null:option.seedColor,gradient:option.gradient,borderRadius:BorderRadius.circular(11)),
                        child:Align(alignment:Alignment.topRight,child:Padding(padding:const EdgeInsets.all(6),child:selected?Icon(Icons.check_circle_rounded,color:option.isGradient?Colors.white:scheme.onPrimary,size:17):const SizedBox(width:17,height:17))),
                      )),
                      const SizedBox(height:7),
                      Row(children:[
                        Expanded(child:Text(option.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
                        if(option.isGradient)Padding(padding:const EdgeInsets.only(left:4),child:Icon(Icons.gradient_rounded,size:14,color:scheme.onSurfaceVariant)),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
  Future<void> _menu(String v)async{if(v=='tariffs'){Navigator.push(context,MaterialPageRoute(builder:(_)=>TariffPage(data:tariffs,onSave:(x)async{tariffs=x;await _saveTariffs();setState((){result=null;_btnStage=_PrimaryBtnStage.calculate;});})));}else if(v=='export'){final dir=await getTemporaryDirectory();final f=File('${dir.path}/AZN_UAH_Calculator_settings.json');await f.writeAsString(const JsonEncoder.withIndent('  ').convert({...tariffs,'rate_history':rateHistory}));await Share.shareXFiles([XFile(f.path)],text:'AZN → UAH Calculator settings');}else if(v=='import'){try{final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);if(picked==null)return;final bytes=picked.files.single.bytes??await File(picked.files.single.path!).readAsBytes();final m=jsonDecode(utf8.decode(bytes));if(m is! Map||m['senders'] is! Map||m['receivers'] is! Map||m['routes'] is! Map)throw FormatException('Файл должен содержать разделы senders, receivers и routes.');for(final entry in (m['routes'] as Map).entries){final parts=entry.key.toString().split('->');if(parts.length!=2||!(m['senders'] as Map).containsKey(parts[0])||!(m['receivers'] as Map).containsKey(parts[1]))throw FormatException('Связь ${entry.key} указывает на отсутствующий банк.');}final imported=Map<String,dynamic>.from(m);if(imported['rate_history'] is List){rateHistory=(imported['rate_history'] as List).whereType().map((e)=>Map<String,dynamic>.from(e)).toList();final dir=await _dir();await File('${dir.path}/rate_history.json').writeAsString(const JsonEncoder.withIndent('  ').convert(rateHistory));}imported.remove('rate_history');setState((){tariffs=imported;_btnStage=_PrimaryBtnStage.calculate;});await _saveTariffs();_message('Настройки импортированы.');}catch(e){_message('Ошибка импорта: $e');}}}
}

enum AmountArtwork { shopping, wallet }

class FintechAmountPainter extends CustomPainter {
  final AmountArtwork artwork;
  const FintechAmountPainter(this.artwork);
  @override
  void paint(Canvas canvas,Size size){
    final sx=size.width/54, sy=size.height/54;
    canvas.save();canvas.scale(sx,sy);
    final shadow=Paint()..color=const Color(0x44000000)..maskFilter=const MaskFilter.blur(BlurStyle.normal,2);
    final bag=Paint()..color=const Color(0xFF65C8FF);
    final bagSide=Paint()..color=const Color(0xFF2874D8);
    final line=Paint()..color=const Color(0xFFB9E8FF)..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round;
    if(artwork==AmountArtwork.shopping){
      final body=Path()..moveTo(9,19)..quadraticBezierTo(9,16,13,16)..lineTo(40,16)..quadraticBezierTo(44,16,44,20)..lineTo(41,43)..quadraticBezierTo(40,47,36,47)..lineTo(13,45)..quadraticBezierTo(9,44,9,40)..close();
      canvas.drawPath(body.shift(const Offset(0,2)),shadow);
      canvas.drawPath(body,bag);
      canvas.drawPath(Path()..moveTo(34,17)..lineTo(41,18)..lineTo(38,44)..lineTo(32,46)..close(),bagSide);
      canvas.drawPath(Path()..moveTo(17,19)..cubicTo(17,3,35,3,36,19),line);
      canvas.drawPath(Path()..moveTo(23,19)..cubicTo(23,10,31,10,31,19),Paint()..color=const Color(0xFF9B8CFF)..style=PaintingStyle.stroke..strokeWidth=2.2);
      final pad=RRect.fromRectAndRadius(const Rect.fromLTWH(28,29,18,13),const Radius.circular(4));
      canvas.drawRRect(pad,Paint()..color=const Color(0xFF153E8A));
      canvas.drawCircle(const Offset(33,35),1.5,Paint()..color=const Color(0xFF6DE5FF));
      canvas.drawCircle(const Offset(40,33),1.3,Paint()..color=const Color(0xFFFFD56A));
      canvas.drawLine(const Offset(36,32),const Offset(36,38),Paint()..color=Colors.white..strokeWidth=1.2);
      canvas.drawLine(const Offset(33,35),const Offset(39,35),Paint()..color=Colors.white..strokeWidth=1.2);
    }else{
      final wallet=RRect.fromRectAndRadius(const Rect.fromLTWH(8,17,36,27),const Radius.circular(7));
      canvas.drawRRect(wallet.shift(const Offset(0,2)),shadow);
      canvas.drawRRect(wallet,Paint()..shader=const LinearGradient(colors:[Color(0xFF7DE7B0),Color(0xFF16A34A)]).createShader(const Rect.fromLTWH(8,17,36,27)));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10,14,30,8),const Radius.circular(5)),Paint()..color=const Color(0xFFFFD36A));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(34,26,15,13),const Radius.circular(4)),Paint()..color=const Color(0xFF16834C));
      canvas.drawCircle(const Offset(39,38),10,Paint()..color=const Color(0xFFE9B84E));
      canvas.drawCircle(const Offset(39,37),7.5,Paint()..color=const Color(0xFFFFD76A));
      final tp=TextPainter(text:const TextSpan(text:'₴',style:TextStyle(color:Color(0xFF9B6419),fontSize:11,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,const Offset(35,30));
      canvas.drawLine(const Offset(13,21),const Offset(31,21),Paint()..color=const Color(0xFFB8FFD1)..strokeWidth=1.5..strokeCap=StrokeCap.round);
    }
    canvas.restore();
  }
  @override bool shouldRepaint(covariant FintechAmountPainter old)=>old.artwork!=artwork;
}

/// Crisp vector broom icon matching the 3D-flat fintech style of FintechAmountPainter.
class BroomResetPainter extends CustomPainter {
  const BroomResetPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    canvas.save();
    canvas.scale(sx, sy);

    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    // Handle (angled top-right to center)
    final handlePath = Path()
      ..moveTo(19.6, 2.6)
      ..lineTo(21.4, 4.4)
      ..lineTo(13.8, 12.0)
      ..lineTo(12.0, 10.2)
      ..close();
    canvas.drawPath(handlePath.shift(const Offset(0, 1.0)), shadow);
    canvas.drawPath(
      handlePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(const Rect.fromLTWH(12, 2, 10, 10)),
    );
    // Gloss line along handle
    canvas.drawLine(
      const Offset(19.4, 3.6),
      const Offset(13.4, 9.6),
      Paint()
        ..color = const Color(0xFFEDE9FE)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );

    // Bristles fan (golden-amber gradient)
    final bristlePath = Path()
      ..moveTo(10.6, 10.4)
      ..lineTo(13.6, 13.4)
      ..quadraticBezierTo(12.8, 17.6, 8.2, 21.2)
      ..quadraticBezierTo(5.6, 19.6, 2.8, 15.8)
      ..quadraticBezierTo(6.4, 11.2, 10.6, 10.4)
      ..close();
    canvas.drawPath(bristlePath.shift(const Offset(0, 1.2)), shadow);
    canvas.drawPath(
      bristlePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(2.5, 10, 11.5, 11.5)),
    );

    // Subtle bristle texture lines
    final strandPaint = Paint()
      ..color = const Color(0xFF92400E).withOpacity(0.55)
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(9.5, 13.4), const Offset(5.2, 17.7), strandPaint);
    canvas.drawLine(const Offset(11.0, 14.8), const Offset(6.8, 19.2), strandPaint);

    // Binding collar (metallic ferrule)
    final collar = Path()
      ..moveTo(10.4, 10.2)
      ..lineTo(11.9, 8.7)
      ..lineTo(15.3, 12.1)
      ..lineTo(13.8, 13.6)
      ..close();
    canvas.drawPath(
      collar,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFEF08A), Color(0xFFEAB308)],
        ).createShader(const Rect.fromLTWH(10, 8.5, 5.5, 5.5)),
    );

    // Two crisp clean sparkles
    void drawSparkle(Offset c, double r, Color color) {
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    drawSparkle(const Offset(4.4, 7.2), 2.1, const Color(0xFF93C5FD));
    drawSparkle(const Offset(17.5, 18.2), 1.8, const Color(0xFFFDE047));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BroomResetPainter oldDelegate) => false;
}

/// Crisp vector "[Shopping Basket] + [Coins & Pouch]" icon for the mini calculator.
class BasketPlusCoinsPainter extends CustomPainter {
  const BasketPlusCoinsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 66.0;
    final sy = size.height / 26.0;
    canvas.save();
    canvas.scale(sx, sy);

    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3);

    // 1. LEFT: Mini royal-blue shopping bag matching AmountArtwork.shopping
    final bagBody = Path()
      ..moveTo(3, 9)
      ..quadraticBezierTo(3, 7.5, 5, 7.5)
      ..lineTo(19, 7.5)
      ..quadraticBezierTo(21, 7.5, 21, 9.5)
      ..lineTo(19.6, 21.5)
      ..quadraticBezierTo(19.2, 23.5, 17.2, 23.5)
      ..lineTo(5.2, 22.8)
      ..quadraticBezierTo(3.2, 22.4, 3, 20.4)
      ..close();
    canvas.drawPath(bagBody.shift(const Offset(0, 1.2)), shadow);
    canvas.drawPath(
      bagBody,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF65C8FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(3, 7.5, 18, 16)),
    );
    // Side fold
    canvas.drawPath(
      Path()
        ..moveTo(16.2, 8)
        ..lineTo(19.6, 8.5)
        ..lineTo(18.2, 22)
        ..lineTo(15.2, 23)
        ..close(),
      Paint()..color = const Color(0xFF1D4ED8),
    );
    // Bag handles
    canvas.drawPath(
      Path()..moveTo(7.2, 9)..cubicTo(7.2, 1.8, 16.5, 1.8, 17.0, 9),
      Paint()
        ..color = const Color(0xFFB9E8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Mini tag
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12.8, 14.2, 8.8, 6.4), const Radius.circular(2.2)),
      Paint()..color = const Color(0xFF153E8A),
    );
    canvas.drawCircle(const Offset(15.5, 17.4), 1.0, Paint()..color = const Color(0xFF6DE5FF));

    // 2. CENTER: Emerald-green Plus (+)
    final plusPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(33, 9.2), const Offset(33, 17.8), plusPaint);
    canvas.drawLine(const Offset(28.7, 13.5), const Offset(37.3, 13.5), plusPaint);

    // 3. RIGHT: Emerald pouch accent + stack of shiny golden coins
    final pouch = RRect.fromRectAndRadius(
      const Rect.fromLTWH(43, 8.5, 17, 13.5),
      const Radius.circular(4),
    );
    canvas.drawRRect(pouch.shift(const Offset(0, 1.2)), shadow);
    canvas.drawRRect(
      pouch,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7DE7B0), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(43, 8.5, 17, 13.5)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(44.5, 7, 13.5, 4), const Radius.circular(2.5)),
      Paint()..color = const Color(0xFFFFD36A),
    );

    // Stacked golden coins in front-right
    void drawCoin(Offset center, double r) {
      canvas.drawCircle(center.translate(0, 1), r, shadow);
      canvas.drawCircle(center, r, Paint()..color = const Color(0xFFD97706));
      canvas.drawCircle(center.translate(0, -0.5), r * 0.82, Paint()..color = const Color(0xFFFFD76A));
      canvas.drawCircle(
        center.translate(0, -0.5),
        r * 0.62,
        Paint()
          ..color = const Color(0xFFB45309).withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    drawCoin(const Offset(58.0, 12.0), 4.6);
    drawCoin(const Offset(55.5, 18.2), 5.3);

    final tp = TextPainter(
      text: const TextSpan(
        text: '₴',
        style: TextStyle(color: Color(0xFF9B6419), fontSize: 6.8, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(53.3, 13.6));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BasketPlusCoinsPainter oldDelegate) => false;
}

class CountryFlagPainter extends CustomPainter {
  final String country;
  const CountryFlagPainter(this.country);
  @override
  void paint(Canvas canvas,Size size){
    final rect=Offset.zero&size;
    final r=RRect.fromRectAndRadius(rect,const Radius.circular(2.5));
    canvas.save();canvas.clipRRect(r);
    if(country=='ua'){
      canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height/2),Paint()..color=const Color(0xFF1677E8));
      canvas.drawRect(Rect.fromLTWH(0,size.height/2,size.width,size.height/2),Paint()..color=const Color(0xFFFFD43B));
    }else{
      final h=size.height/3;
      canvas.drawRect(Rect.fromLTWH(0,0,size.width,h),Paint()..color=const Color(0xFF00A3DD));
      canvas.drawRect(Rect.fromLTWH(0,h,size.width,h),Paint()..color=const Color(0xFFED2939));
      canvas.drawRect(Rect.fromLTWH(0,h*2,size.width,h),Paint()..color=const Color(0xFF3F9C35));
      final cx=size.width*.43,cy=size.height*.5,rad=size.height*.22;
      canvas.drawCircle(Offset(cx,cy),rad,Paint()..color=Colors.white);
      canvas.drawCircle(Offset(cx+rad*.38,cy-rad*.08),rad*.82,Paint()..color=const Color(0xFFED2939));
      final star=Path();
      for(var i=0;i<16;i++){final a=-math.pi/2+i*math.pi/8;final rr=i.isEven?size.height*.105:size.height*.045;final pt=Offset(size.width*.68+math.cos(a)*rr,size.height*.5+math.sin(a)*rr);if(i==0)star.moveTo(pt.dx,pt.dy);else star.lineTo(pt.dx,pt.dy);}
      star.close();canvas.drawPath(star,Paint()..color=Colors.white);
    }
    canvas.restore();
    canvas.drawRRect(r,Paint()..color=const Color(0x55FFFFFF)..style=PaintingStyle.stroke..strokeWidth=.6);
  }
  @override bool shouldRepaint(covariant CountryFlagPainter old)=>old.country!=country;
}

class RateSparklinePainter extends CustomPainter {
  final List<double> values;
  RateSparklinePainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final points=values.length<2?[.35,.52,.42,.68,.60,.82,.72,.95]:values;
    final minValue=points.reduce((a,b)=>a<b?a:b), maxValue=points.reduce((a,b)=>a>b?a:b);
    final span=(maxValue-minValue).abs()<0.000001?1.0:(maxValue-minValue);
    final path=Path();
    for(var i=0;i<points.length;i++){
      final x=size.width*i/(points.length-1);
      final y=size.height-5-((points[i]-minValue)/span)*(size.height-10);
      if(i==0){path.moveTo(x,y);}else{final previousX=size.width*(i-1)/(points.length-1);final previousY=size.height-5-((points[i-1]-minValue)/span)*(size.height-10);final mid=(previousX+x)/2;path.cubicTo(mid,previousY,mid,y,x,y);}
    }
    final fill=Path.from(path)..lineTo(size.width,size.height)..lineTo(0,size.height)..close();
    final rect=Offset.zero&size;
    final shader=const LinearGradient(colors:[Color(0xFFA855F7),Color(0xFF34D399)]).createShader(rect);
    canvas.drawPath(fill,Paint()..shader=const LinearGradient(colors:[Color(0x55A855F7),Color(0x0034D399)],begin:Alignment.topCenter,end:Alignment.bottomCenter).createShader(rect)..style=PaintingStyle.fill);
    canvas.drawPath(path,Paint()..shader=shader..style=PaintingStyle.stroke..strokeWidth=5.5..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    canvas.drawPath(path,Paint()..shader=shader..style=PaintingStyle.stroke..strokeWidth=2.5..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
  }
  @override bool shouldRepaint(covariant RateSparklinePainter oldDelegate)=>oldDelegate.values!=values;
}

class MiniCalcDialog extends StatefulWidget {
  final ValueChanged<double> onAddToCart;
  const MiniCalcDialog({super.key, required this.onAddToCart});
  @override
  State<MiniCalcDialog> createState() => _MiniCalcDialogState();
}

class _MiniCalcDialogState extends State<MiniCalcDialog> {
  String expression = '0';
  String? error;
  String? lastAnswer;
  int _addedCount = 0;

  static const _keys = <List<String>>[
    ['AC', '⌫', '(', ')'],
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['±', '0', '.', '+'],
    ['%', '00', '=', ''],
  ];

  bool get _endsWithOperator =>
      expression.isNotEmpty && RegExp(r'[+−×÷.]$').hasMatch(expression);

  void _press(String key) {
    HapticFeedback.lightImpact();
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
        expression = expression.startsWith('−')
            ? expression.substring(1)
            : '−($expression)';
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
        if (expression == '0' && key == '(') expression = '(';
        else expression += key;
        lastAnswer = null;
      }
    });
  }

  String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) return value.toInt().toString();
    return value.toStringAsPrecision(10).replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  void _addCurrentToBasketAndCoins() {
    HapticFeedback.lightImpact();
    try {
      final value = _ExpressionParser(expression).parse();
      if (!value.isFinite || value <= 0) {
        setState(() => error = 'Введите сумму больше 0');
        return;
      }
      widget.onAddToCart(value);
      setState(() {
        _addedCount++;
        expression = '0';
        lastAnswer = null;
        error = null;
      });
    } catch (_) {
      setState(() => error = 'Проверьте выражение');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            children: [
              Row(children: [
                IconButton(
                  tooltip: 'Назад',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Expanded(
                  child: Text(
                    'Калькулятор',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
                _buildBasketPlusCoinsAction(scheme),
              ]),
              const SizedBox(height: 18),
              Card(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 132),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomRight,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (lastAnswer != null) Text('Результат', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(expression, maxLines: 1, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    ),
                    if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final spacing = 9.0;
                  final buttonHeight = ((constraints.maxHeight - spacing * 5) / 6).clamp(44.0, 82.0).toDouble();
                  return Column(children: [
                    for (final row in _keys)
                      Expanded(child: Padding(
                        padding: EdgeInsets.only(bottom: row == _keys.last ? 0 : spacing),
                        child: Row(children: [
                          for (final key in row)
                            if (key.isNotEmpty)
                              Expanded(child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: SizedBox(
                                  height: buttonHeight,
                                  child: FilledButton.tonal(
                                    onPressed: () => _press(key),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: key == '=' ? scheme.primary :
                                        (['+', '−', '×', '÷', '%'].contains(key) ? scheme.secondaryContainer : scheme.surfaceContainerHighest),
                                      foregroundColor: key == '=' ? scheme.onPrimary : scheme.onSurface,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      textStyle: TextStyle(fontSize: key.length > 1 ? 16 : 22, fontWeight: FontWeight.w700),
                                    ),
                                    child: Text(key == '÷' ? '÷' : key == '×' ? '×' : key),
                                  ),
                                ),
                              )),
                        ]),
                      )),
                  ]);
                }),
              ),
              const SizedBox(height: 10),
              Text(
                'Нажмите значок корзинки и монеток, чтобы добавить сумму в покупку и +100 UAH в услугу',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasketPlusCoinsAction(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Добавить в покупку и +100 UAH в услугу',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addCurrentToBasketAndCoins,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252A36) : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF3A4256) : scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 66,
                  height: 26,
                  child: CustomPaint(painter: BasketPlusCoinsPainter()),
                ),
                if (_addedCount > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_addedCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recursive-descent parser: supports + − × ÷, unary signs, parentheses,
/// decimal numbers and postfix percent. Invalid trailing characters are rejected.
class _ExpressionParser {
  _ExpressionParser(String source) : _source = source.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-').replaceAll(',', '.');
  final String _source;
  int _index = 0;

  double parse() {
    final value = _sum();
    _spaces();
    if (_index != _source.length) throw const FormatException('Лишние символы');
    return value;
  }

  void _spaces() { while (_index < _source.length && _source[_index].trim().isEmpty) { _index++; } }
  bool _take(String char) { _spaces(); if (_index < _source.length && _source[_index] == char) { _index++; return true; } return false; }

  double _sum() {
    var value = _product();
    while (true) {
      if (_take('+')) value += _product();
      else if (_take('-')) value -= _product();
      else return value;
    }
  }

  double _product() {
    var value = _unary();
    while (true) {
      if (_take('*')) value *= _unary();
      else if (_take('/')) {
        final divisor = _unary();
        if (divisor == 0) throw const FormatException('Деление на ноль');
        value /= divisor;
      } else return value;
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
      if (c == '.') { dots++; if (dots > 1) break; _index++; }
      else if (RegExp(r'\d').hasMatch(c)) { _index++; }
      else break;
    }
    if (start == _index) throw const FormatException('Ожидалось число');
    return double.parse(_source.substring(start, _index));
  }
}

class TariffPage extends StatefulWidget{final Map<String,dynamic> data;final ValueChanged> onSave;const TariffPage({super.key,required this.data,required this.onSave});@override State<TariffPage> createState()=>_TariffPageState();}
class _TariffPageState extends State<TariffPage>{late Map<String,dynamic> data;String tab='senders',routeSender='',routeReceiver='';final fields=<String,TextEditingController>{};bool routeVerified=false;String routeMode='add_on';@override void initState(){super.initState();data=jsonDecode(jsonEncode(widget.data));routeSender=(data['senders'] as Map).keys.first;routeReceiver=(data['receivers'] as Map).keys.first;_loadRoute();}
void _loadRoute(){final r=data['routes']['$routeSender->$routeReceiver']??{};final s=r['sender']??{};final t=r['receiver']??{};for(final k in ['percent_fee','fixed_fee_azn','conversion_fee_percent','min_fee_azn','max_fee_azn','receiver_percent_fee','fixed_fee_uah','min_fee_uah','max_fee_uah']){fields[k]?.dispose();}fields.clear();for(final k in ['percent_fee','fixed_fee_azn','conversion_fee_percent','min_fee_azn','max_fee_azn'])fields[k]=TextEditingController(text:s[k]?.toString()??(k.startsWith('min_')||k.startsWith('max_')?'':'0'));for(final k in ['receiver_percent_fee','fixed_fee_uah','min_fee_uah','max_fee_uah']){final src=k=='receiver_percent_fee'?'percent_fee':k;fields[k]=TextEditingController(text:t[src]?.toString()??(k.startsWith('min_')||k.startsWith('max_')?'':'0'));}routeMode=s['fee_mode']??'add_on';routeVerified=r['verified']==true;}
void _saveRoute(){final s=data['senders'][routeSender];final r=data['receivers'][routeReceiver];data['routes']['$routeSender->$routeReceiver']={'sender':{'name':s['name'],'percent_fee':fields['percent_fee']!.text,'fixed_fee_azn':fields['fixed_fee_azn']!.text,'conversion_fee_percent':fields['conversion_fee_percent']!.text,'min_fee_azn':fields['min_fee_azn']!.text.isEmpty?null:fields['min_fee_azn']!.text,'max_fee_azn':fields['max_fee_azn']!.text.isEmpty?null:fields['max_fee_azn']!.text,'fee_mode':routeMode},'receiver':{'name':r['name'],'percent_fee':fields['receiver_percent_fee']!.text,'fixed_fee_uah':fields['fixed_fee_uah']!.text,'min_fee_uah':fields['min_fee_uah']!.text.isEmpty?null:fields['min_fee_uah']!.text,'max_fee_uah':fields['max_fee_uah']!.text.isEmpty?null:fields['max_fee_uah']!.text},'verified':routeVerified};}
Widget _editBankGroup(String group){final map=data[group] as Map<String,dynamic>;return ListView(padding:const EdgeInsets.all(12),children:[...map.entries.map((entry){final key=entry.key;final item=entry.value as Map<String,dynamic>;final sender=group=='senders';final names=sender?['fixed_fee_azn','percent_fee','conversion_fee_percent','min_fee_azn','max_fee_azn']:['fixed_fee_uah','percent_fee','min_fee_uah','max_fee_uah'];return Card(child:ExpansionTile(title:Text('${item['name']} [$key]'),children:[Padding(padding:const EdgeInsets.all(12),child:Column(children:[...names.map((f)=>TextFormField(initialValue:item[f]?.toString()??'',keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:_tariffLabel(f,!sender),hintText:f.startsWith('max_')?'пусто = без ограничения':'0'),onChanged:(v)=>item[f]=v.isEmpty&&f.startsWith('max_')?null:(v.isEmpty?'0':v))),if(sender)DropdownButtonFormField<String>(value:item['fee_mode']??'add_on',decoration:const InputDecoration(labelText:'Способ удержания'),items:const [DropdownMenuItem(value:'add_on',child:Text('Комиссия сверху (add_on)')),DropdownMenuItem(value:'deducted',child:Text('Удерживается (deducted)'))],onChanged:(v)=>item['fee_mode']=v),CheckboxListTile(value:item['verified']==true,title:const Text('Тариф проверен и подтверждён'),onChanged:(v)=>setState(()=>item['verified']=v==true)),Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:(){setState((){map.remove(key);(data['routes'] as Map).removeWhere((rk,_)=>rk.toString().startsWith('$key->')||rk.toString().endsWith('->$key'));});},icon:const Icon(Icons.delete_outline),label:const Text('Удалить банк')))]))]));}),OutlinedButton.icon(onPressed:()=>_addBank(group),icon:const Icon(Icons.add),label:const Text('Добавить банк'))]);}
Future<void> _addBank(String group)async{final name=TextEditingController(),key=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Новый банк'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Название')),TextField(controller:key,decoration:const InputDecoration(labelText:'Уникальный ключ (латиница)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Добавить'))]));if(ok==true&&name.text.trim().isNotEmpty&&key.text.trim().isNotEmpty){final k=key.text.trim().toLowerCase().replaceAll(' ','_');final map=data[group] as Map<String,dynamic>;if(map.containsKey(k)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Такой идентификатор уже существует')));return;}map[k]=group=='senders'?_sender(name.text.trim()):_receiver(name.text.trim());setState((){});}}
Widget _routeEditor(){final send=data['senders'] as Map<String,dynamic>,recv=data['receivers'] as Map<String,dynamic>;return ListView(padding:const EdgeInsets.all(12),children:[const Text('Индивидуальные правила для пары банков имеют приоритет над общими тарифами. Значения не копируются автоматически.'),DropdownButtonFormField<String>(value:routeSender,decoration:const InputDecoration(labelText:'Банк отправителя'),items:send.keys.map((k)=>DropdownMenuItem(value:k,child:Text(send[k]['name']))).toList(),onChanged:(v)=>setState((){routeSender=v!;_loadRoute();})),DropdownButtonFormField<String>(value:routeReceiver,decoration:const InputDecoration(labelText:'Банк получателя'),items:recv.keys.map((k)=>DropdownMenuItem(value:k,child:Text(recv[k]['name']))).toList(),onChanged:(v)=>setState((){routeReceiver=v!;_loadRoute();})),...['percent_fee','fixed_fee_azn','conversion_fee_percent','min_fee_azn','max_fee_azn'].map((k)=>_routeField(k)),DropdownButtonFormField<String>(value:routeMode,decoration:const InputDecoration(labelText:'Способ удержания'),items:const [DropdownMenuItem(value:'add_on',child:Text('Комиссия сверху')),DropdownMenuItem(value:'deducted',child:Text('Удерживается'))],onChanged:(v)=>setState(()=>routeMode=v!)),const Divider(),...['receiver_percent_fee','fixed_fee_uah','min_fee_uah','max_fee_uah'].map((k)=>_routeField(k)),CheckboxListTile(value:routeVerified,onChanged:(v)=>setState(()=>routeVerified=v==true),title:const Text('Тариф этой связки проверен')),FilledButton(onPressed:(){_saveRoute();setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Тариф связки сохранён')));},child:const Text('Сохранить тариф связки')),TextButton(onPressed:(){data['routes'].remove('$routeSender->$routeReceiver');_loadRoute();setState((){});},child:const Text('Удалить тариф связки'))]);}
Widget _routeField(String k)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:TextField(controller:fields[k],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:_tariffLabel(k,k.startsWith('receiver_')||k.endsWith('_uah')),hintText:k.startsWith('max_')||k.startsWith('min_')?'пусто = наследовать из базового тарифа':'0')));
String _tariffLabel(String key,bool receiver){switch(key){case 'percent_fee':case 'receiver_percent_fee':return receiver?'Комиссия банка получателя (%)':'Комиссия отправителя (%)';case 'fixed_fee_azn':return 'Фикс. комиссия отправителя (AZN)';case 'min_fee_azn':return 'Мин. комиссия отправителя (AZN)';case 'max_fee_azn':return 'Макс. комиссия отправителя (AZN)';case 'conversion_fee_percent':return 'Комиссия конвертации / буфер курса (%)';case 'fixed_fee_uah':return 'Фикс. комиссия получателя (UAH)';case 'min_fee_uah':return 'Мин. комиссия получателя (UAH)';case 'max_fee_uah':return 'Макс. комиссия получателя (UAH)';default:return key;}}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Настройки банков и тарифов'),actions:[TextButton(onPressed:(){_saveRoute();widget.onSave(data);Navigator.pop(c);},child:const Text('СОХРАНИТЬ'))]),body:Column(children:[const Padding(padding:EdgeInsets.all(12),child:Text('Новые тарифы создаются неподтверждёнными. Подтверждайте их только после проверки официальных условий банка.')),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final t in ['senders','receivers','routes'])Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(label:Text(t=='senders'?'Отправители':t=='receivers'?'Получатели':'Связки банков'),selected:tab==t,onSelected:(_)=>setState(()=>tab=t)))])),Expanded(child:tab=='routes'?_routeEditor():_editBankGroup(tab))]));}
