import 'package:flutter/material.dart';

import 'deck_ballast_sequence.dart';

const _navy = Color(0xFF081522);
const _panel = Color(0xFF112437);
const _accent = Color(0xFF4DDAC6);
const _muted = Color(0xFF9BB0C3);
const _outline = Color(0xFF294155);

class BallastTimeScreen extends StatefulWidget {
  const BallastTimeScreen({super.key});
  @override
  State<BallastTimeScreen> createState() => _BallastTimeScreenState();
}

class _BallastTimeScreenState extends State<BallastTimeScreen> {
  final _form = GlobalKey<FormState>();
  final _volume = TextEditingController();
  final _rate = TextEditingController();
  late DateTime _start;
  DateTime? _finish;
  double? _exactMinutes;
  int? _roundedMinutes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _start = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _volume.dispose();
    _rate.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  void _clear() {
    setState(() {
      _finish = null;
      _exactMinutes = null;
      _roundedMinutes = null;
    });
  }

  String _two(int value) => value.toString().padLeft(2, '0');
  String _date(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';
  String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(_start.year, _start.month, _start.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: 'START DATE (UTC)',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
      helpText: 'START TIME (UTC)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _start = DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);
      _finish = null;
      _exactMinutes = null;
      _roundedMinutes = null;
    });
  }

  void _calculate() {
    if (!_form.currentState!.validate()) return;
    final minutes = _parse(_volume.text)! / _parse(_rate.text)! * 60;
    try {
      if (!minutes.isFinite || minutes > 1000000000) {
        throw const FormatException('Calculation range exceeded');
      }
      final rounded = minutes.round();
      final finish = _start.add(Duration(minutes: rounded));
      setState(() {
        _exactMinutes = minutes;
        _roundedMinutes = rounded;
        _finish = finish;
      });
    } catch (_) {
      _clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Values exceed the supported calculation range.'),
      ));
    }
  }

  Widget _field(TextEditingController controller, String label,
      String unit, {bool allowZero = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          filled: true,
          fillColor: _navy,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (_) => _clear(),
        validator: (text) {
          final value = _parse(text ?? '');
          if (value == null) return 'Enter a finite number.';
          if (allowZero ? value < 0 : value <= 0) {
            return allowZero ? 'Value must be zero or greater.'
                : 'Value must be greater than zero.';
          }
          return null;
        },
      ),
    );
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _outline),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final minutes = _roundedMinutes;
    final duration = minutes == null ? '—'
        : '${minutes ~/ 1440} d  ${_two((minutes % 1440) ~/ 60)} h  '
          '${_two(minutes % 60)} min';
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(title: const Text('Ballast Time')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.water_outlined, color: _accent, size: 46),
            const SizedBox(height: 20),
            const Text('Ballast Time Calculator', style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('Estimated pumping duration and completion time.',
              style: TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => BallastSequenceScreen(start: _start),
                )),
                child: const Text('Ballast Sequence'),
              ),
            ),
            const SizedBox(height: 24),
            _card(Form(key: _form, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_volume, 'Volume to Pump', 'm³', allowZero: true),
                _field(_rate, 'Total Effective Pump Rate', 'm³/h'),
                const Text('START DATE & TIME (UTC)',
                  style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('${_date(_start)}  ${_time(_start)} UTC'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _calculate,
                  style: FilledButton.styleFrom(backgroundColor: _accent,
                    foregroundColor: _navy,
                    padding: const EdgeInsets.all(18)),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calculate'),
                ),
              ],
            ))),
            const SizedBox(height: 24),
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ESTIMATED DURATION',
                style: TextStyle(color: _muted, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              Text(duration, style: const TextStyle(color: _accent,
                fontSize: 28, fontWeight: FontWeight.w700)),
              if (_exactMinutes != null) ...[
                const SizedBox(height: 8),
                Text('Calculated: ${_exactMinutes!.toStringAsFixed(2)} min. '
                  'Schedule rounded to the nearest minute.',
                  style: const TextStyle(color: _muted, height: 1.5)),
              ],
              const SizedBox(height: 24),
              const Text('ESTIMATED COMPLETION (UTC)',
                style: TextStyle(color: _muted, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              Text(_finish == null ? '—'
                  : '${_date(_finish!)}  ${_time(_finish!)} UTC',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              const Text('Assumes a constant effective pump rate. '
                'Include the combined effective rate when using multiple pumps. '
                'Stripping, interruptions and changing flow are not included.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
            ])),
          ]),
        )),
      ),
    );
  }
}
