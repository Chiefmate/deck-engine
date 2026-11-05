import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'eta_model.dart';
import 'deck_eco_speed.dart';

const _navy = Color(0xFF081522);
const _panel = Color(0xFF112437);
const _accent = Color(0xFF4DDAC6);
const _muted = Color(0xFF9BB0C3);
const _outline = Color(0xFF294155);

class EtaCalculatorScreen extends StatefulWidget {
  const EtaCalculatorScreen({super.key});
  @override
  State<EtaCalculatorScreen> createState() => _EtaCalculatorScreenState();
}
class _EtaCalculatorScreenState extends State<EtaCalculatorScreen> {
  final _form = GlobalKey<FormState>();
  final _distance = TextEditingController();
  final _speed = TextEditingController();
  bool _required = false;
  int _modeRevision = 0;
  int _departureOffset = 0, _arrivalOffset = 0;
  late DateTime _departure, _target;
  EtaResult? _result;
  String? _error;
  @override
  void initState() {
    super.initState(); final now = DateTime.now().toUtc();
    _departure = DateTime.utc(now.year,now.month,now.day,now.hour,now.minute);
    _target = _departure.add(const Duration(days: 1));
  }
  @override
  void dispose() { _distance.dispose(); _speed.dispose(); super.dispose(); }
  double? _parse(String text) {
    final v = double.tryParse(text.trim().replaceAll(',','.'));
    return v != null && v.isFinite ? v : null;
  }
  void _invalidate() { _result = null; _error = null; }
  InputDecoration _decoration(String label) => InputDecoration(labelText: label,filled: true,
    fillColor: _navy,errorMaxLines: 3,border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
  Widget _card(Widget child) => Container(width: double.infinity,padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _panel,borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _outline)),child: child);
  Widget _number(TextEditingController c,String label) => Padding(padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(controller: c,decoration: _decoration(label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(_invalidate),validator: (text) {
        final v = _parse(text ?? ''); return v == null || v <= 0 ? 'Enter a positive finite number.' : null;
      }));
  Future<void> _pickTime(bool departure) async {
    final current = departure ? _departure : _target;
    final day = await showDatePicker(context: context,
      initialDate: DateTime(current.year,current.month,current.day),
      firstDate: DateTime(2000),lastDate: DateTime(2100,12,31));
    if (day == null || !mounted) return;
    final clock = await showTimePicker(context: context,
      initialTime: TimeOfDay(hour: current.hour,minute: current.minute),
      builder: (context,child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink()));
    if (clock == null || !mounted) return;
    final value = DateTime.utc(day.year,day.month,day.day,clock.hour,clock.minute);
    setState(() { if (departure) { _departure = value; } else { _target = value; } _invalidate(); });
  }
  Widget _dateField(bool departure) {
    final offset = departure ? _departureOffset : _arrivalOffset;
    final time = departure ? _departure : _target;
    return Padding(padding: const EdgeInsets.only(bottom: 20),child: InkWell(
      onTap: () => _pickTime(departure),borderRadius: BorderRadius.circular(14),child: InputDecorator(
        decoration: _decoration('${departure ? 'Departure Time' : 'Target Arrival'} (${etaOffsetLabel(offset)})'),
        child: Row(children: [Expanded(child: Text(etaDateTime(time))),
          const Icon(Icons.calendar_month_outlined,color: _accent)]))));
  }
  Widget _zone(bool departure) => Padding(padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<int>(value: departure ? _departureOffset : _arrivalOffset,
      isExpanded: true,decoration: _decoration(departure ? 'Departure UTC Offset' : 'Arrival UTC Offset'),
      items: [for (var m=-720;m<=840;m+=15) DropdownMenuItem(value: m,child: Text(etaOffsetLabel(m)))],
      onChanged: (v) { if (v == null) return; setState(() {
        if (departure) { _departureOffset = v; } else { _arrivalOffset = v; } _invalidate();
      }); }));
  void _calculate() {
    if (!_form.currentState!.validate()) return;
    try {
      final start = portTimeToUtc(_departure,_departureOffset);
      final result = _required
        ? EtaResult.requiredSpeed(distanceNM: _parse(_distance.text)!,departureUTC: start,
            targetArrivalUTC: portTimeToUtc(_target,_arrivalOffset))
        : EtaResult.calculateEta(distanceNM: _parse(_distance.text)!,speedKnots: _parse(_speed.text)!,departureUTC: start);
      setState(() { _result = result; _error = null; });
    } on FormatException catch (e) { setState(() { _result = null; _error = e.message; }); }
    on ArgumentError { setState(() { _result = null; _error = 'Calculated date is outside the supported range.'; }); }
  }
  String _report(EtaResult r) {
    final localDeparture = utcToPortTime(r.departureUTC,_departureOffset);
    final localArrival = utcToPortTime(r.arrivalUTC,_arrivalOffset);
    final hours = r.duration.inMicroseconds / Duration.microsecondsPerHour;
    return 'ETA CALCULATOR\nMode: ${r.requiredSpeedMode ? 'Required Average Speed' : 'Calculate ETA'}\n'
      'Distance: ${r.distanceNM} NM\n'
      'Departure: ${etaDateTime(localDeparture)} ${etaOffsetLabel(_departureOffset)}\n'
      'Departure UTC: ${etaDateTime(r.departureUTC)}\n'
      '${r.requiredSpeedMode ? 'Target arrival' : 'ETA'}: ${etaDateTime(localArrival)} ${etaOffsetLabel(_arrivalOffset)}\n'
      'Arrival UTC: ${etaDateTime(r.arrivalUTC)}\n'
      'Time to go: ${etaDuration(r.duration)} (${hours.toStringAsFixed(8)} hours)\n'
      'Average speed over ground: ${r.averageSpeedKnots.toStringAsFixed(8)} kts\n'
      '${r.requiredSpeedMode ? 'Displayed required speed: ${r.requiredSpeedRounded.toStringAsFixed(2)} kts (rounded upward)\nFormula: ${r.distanceNM} / $hours = ${r.averageSpeedKnots} kts' : 'Formula: ${r.distanceNM} / ${r.averageSpeedKnots} = ${r.distanceNM / r.averageSpeedKnots} hours'}\n'
      'No stops or delays included. UTC offsets are entered manually and do not change automatically for DST.';
  }
  Future<void> _copy(EtaResult r) async {
    try {
      await Clipboard.setData(ClipboardData(text: _report(r)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calculation copied.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not copy the calculation.')));
    }
  }
  Widget _resultCard(EtaResult r) {
    final localArrival = utcToPortTime(r.arrivalUTC,_arrivalOffset);
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
      Text(r.requiredSpeedMode ? 'REQUIRED SPEED' : 'ESTIMATED TIME OF ARRIVAL',
        style: const TextStyle(color: _muted,letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Text(r.requiredSpeedMode ? '${r.requiredSpeedRounded.toStringAsFixed(2)} kts'
          : etaDateTime(localArrival),style: const TextStyle(color: _accent,fontSize: 30,fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(r.requiredSpeedMode ? 'Average speed over ground; rounded upward to 0.01 kt.' : etaOffsetLabel(_arrivalOffset),
        style: const TextStyle(color: _muted)),
      const SizedBox(height: 20),
      Text('Time to go: ${etaDuration(r.duration)}'),
      const SizedBox(height: 10),
      Text('Arrival UTC: ${etaDateTime(r.arrivalUTC)}'),
      if (r.requiredSpeedMode) ...[const SizedBox(height: 10),
        Text('Target arrival: ${etaDateTime(localArrival)} ${etaOffsetLabel(_arrivalOffset)}'),
        const SizedBox.shrink()],
      const SizedBox(height: 16),
      Text(r.requiredSpeedMode ? 'Required speed = Distance / Available time'
        : 'Passage time = Distance / Average speed',style: const TextStyle(color: _muted)),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: () => _copy(r),icon: const Icon(Icons.copy_outlined),label: const Text('Copy Calculation')),
    ]));
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _navy,
    appBar: AppBar(title: const Text('ETA Calculator')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20),child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        const Text('Passage Planning',style: TextStyle(fontSize: 25,fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(key: ValueKey(_modeRevision),value: _required ? 'speed' : 'eta',isExpanded: true,decoration: _decoration('Calculation Mode'),
          items: const [DropdownMenuItem(value: 'eta',child: Text('Calculate ETA')),
            DropdownMenuItem(value: 'speed',child: Text('Required Average Speed')), DropdownMenuItem(value: 'eco',child: Text('Eco / Full Speed'))],
          onChanged: (v) async { if (v == 'eco') { await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EcoSpeedScreen())); if (mounted) setState(() => _modeRevision++); return; } if (v != null) setState(() { _required = v == 'speed'; _invalidate(); }); }),
      ])),
      const SizedBox(height: 24),
      Form(key: _form,child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        _number(_distance,'Distance / Remaining Distance (NM)'),
        _dateField(true),
        Align(alignment: Alignment.centerLeft,child: TextButton.icon(onPressed: () {
          final now = DateTime.now().toUtc();
          final minute = DateTime.utc(now.year,now.month,now.day,now.hour,now.minute);
          setState(() { _departure = utcToPortTime(minute,_departureOffset); _invalidate(); });
        },icon: const Icon(Icons.schedule),label: const Text('Use Current Time'))),
        const SizedBox(height: 12),
        if (_required) _dateField(false) else _number(_speed,'Planned Speed (kts)'),
        _card(ExpansionTile(tilePadding: EdgeInsets.zero,childrenPadding: EdgeInsets.zero,
          title: const Text('Port Time Zones'),subtitle: Text(
            'Departure: ${etaOffsetLabel(_departureOffset)} • Arrival: ${etaOffsetLabel(_arrivalOffset)}',
            style: const TextStyle(color: _muted)),children: [
            const SizedBox(height: 16),_zone(true),_zone(false),
            const Padding(padding: EdgeInsets.only(bottom: 16),child: Text(
              'Offsets apply to the entered port times. Set the offsets for the voyage dates; daylight-saving changes are not automatic.',
              style: TextStyle(color: _muted,height: 1.5))),
          ])),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: _calculate,icon: const Icon(Icons.calculate_outlined),
          style: FilledButton.styleFrom(backgroundColor: _accent,foregroundColor: _navy,padding: const EdgeInsets.all(20)),
          label: Text(_required ? 'Calculate Required Speed' : 'Calculate ETA')),
      ])),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 18),child: Text(_error!,
        style: const TextStyle(color: Color(0xFFFFB4AB)))),
      if (_result != null) ...[const SizedBox(height: 24),_resultCard(_result!)],
      const SizedBox(height: 18),
      const Text('Use average speed over ground (SOG). No stops or delays are included.',
        style: TextStyle(color: _muted,fontSize: 12,height: 1.5)),
    ])),
  )));
}
