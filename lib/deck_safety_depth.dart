import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'safety_depth_model.dart';
import 'safety_depth_report.dart';

const _navy = Color(0xFF081522);
const _panel = Color(0xFF112437);
const _accent = Color(0xFF4DDAC6);
const _muted = Color(0xFF9BB0C3);
const _outline = Color(0xFF294155);

class SafetyDepthStore {
  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();
  static Future<void> _queue = Future<void>.value();
  static const profileKey = 'deck_safety_vessel_v3';
  static const inputsKey = 'deck_safety_inputs_v3';
  static Future<T> _run<T>(Future<T> Function() action) {
    final task = _queue.then((_) => action());
    _queue = task.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return task;
  }
  static Future<Map<String, dynamic>> load() => _run(() async {
    final profileText = await _prefs.getString(profileKey);
    final inputsText = await _prefs.getString(inputsKey);
    VesselSafetySettings? profile;
    bool migrated = false;
    if (profileText != null) {
      profile = VesselSafetySettings.fromJson(Map<String,dynamic>.from(jsonDecode(profileText) as Map));
    } else {
      final previous = await _prefs.getString('deck_safety_vessel_v2');
      if (previous != null) {
        final old = Map<String,dynamic>.from(jsonDecode(previous) as Map);
        profile = VesselSafetySettings(name: old['name'] as String,
          lengthBP: (old['lengthBP'] as num).toDouble(), breadth: (old['breadth'] as num).toDouble(),
          cbMethod: calculateCbMethod);
        profile.validate(); migrated = true;
      }
    }
    return {'profile': profile, 'reviewSettings': migrated,
      'inputs': inputsText == null ? <String,dynamic>{} : Map<String,dynamic>.from(jsonDecode(inputsText) as Map)};
  });
  static Future<void> saveProfile(VesselSafetySettings profile) => _run(() async {
    profile.validate(); await _prefs.setString(profileKey,jsonEncode(profile.toJson()));
  });
  static Future<void> saveInputs(Map<String,dynamic> input) {
    final text = jsonEncode(input);
    return _run(() => _prefs.setString(inputsKey,text));
  }
}

double? _parse(String? text) {
  final v = double.tryParse((text ?? '').trim().replaceAll(',','.'));
  return v != null && v.isFinite ? v : null;
}
InputDecoration _decoration(String label, {String? help}) => InputDecoration(
  labelText: label, helperText: help, helperMaxLines: 3, errorMaxLines: 3,
  filled: true, fillColor: _navy,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
Widget _card(Widget child) => Container(width: double.infinity,
  padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _panel,
    borderRadius: BorderRadius.circular(20),border: Border.all(color: _outline)),child: child);

class SafetyDepthScreen extends StatefulWidget {
  const SafetyDepthScreen({super.key});
  @override
  State<SafetyDepthScreen> createState() => _SafetyDepthScreenState();
}
class _SafetyDepthScreenState extends State<SafetyDepthScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String,TextEditingController>{
    for (final key in ['fore','aft','displacement','depth','speed','heel','density','waterDensity','tableCb','manualDepth','depthBasis'])
      key: TextEditingController(text: key == 'waterDensity' ? '1.025' : ['heel','density'].contains(key) ? '0' : ''),
  };
  VesselSafetySettings? _vessel;
  SafetyDepthResult? _result;
  String? _catzoc, _error, _loadError;
  bool _loading = true, _saving = false, _exporting = false, _restored = false, _reviewSettings = false;
  bool get _busy => _saving || _exporting;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in _fields.values) { c.dispose(); } super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await SafetyDepthStore.load();
      if (!mounted) return;
      final values = data['inputs'] as Map<String,dynamic>;
      for (final e in _fields.entries) {
        if (values[e.key] is String) e.value.text = values[e.key] as String;
      }
      final category = values['catzoc'];
      setState(() {
        _vessel = data['profile'] as VesselSafetySettings?;
        _reviewSettings = data['reviewSettings'] as bool;
        _restored = values.isNotEmpty;
        _catzoc = ['A1','A2','B','C','D','U'].contains(category) ? category as String : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadError = 'Saved settings could not be loaded.'; });
    }
  }
  void _invalidate() => setState(() { _result = null; _error = null; });
  Future<void> _settings() async {
    final value = await Navigator.of(context).push<VesselSafetySettings>(MaterialPageRoute(
      builder: (_) => _VesselParticularsScreen(settings: _vessel)));
    if (!mounted || value == null) return;
    setState(() { _vessel = value; _reviewSettings = false; _result = null; _error = null; });
  }
  Widget _number(String key,String label,{bool positive = false,bool signed = false,String? help}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),child: TextFormField(
      key: ValueKey(key),controller: _fields[key],enabled: !_busy,
      keyboardType: TextInputType.numberWithOptions(decimal: true,signed: signed),
      decoration: _decoration(label,help: help),onChanged: (_) => _invalidate(),
      validator: (text) {
        final v = _parse(text);
        if (v == null) return 'Enter a finite number.';
        if (key == 'heel') return v.abs() >= 90 ? 'Use an angle between -90 and 90 degrees.' : null;
        if (positive ? v <= 0 : v < 0) return positive ? 'Value must be greater than zero.' : 'Enter 0 or a positive value.';
        if (key == 'tableCb' && v > 1) return 'Cb must not exceed 1.';
        return null;
      },
    ));
  Widget _derived(String label,double? value,{String unit = 'm'}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),child: InputDecorator(
      decoration: _decoration(label),child: Text(value == null ? '—' : '${value.toStringAsFixed(unit == 'm' ? 3 : 6)} $unit',
        style: const TextStyle(color: _accent,fontWeight: FontWeight.w600))));
  Future<void> _calculate() async {
    final vessel = _vessel;
    if (vessel == null || _reviewSettings || !_form.currentState!.validate()) return;
    double v(String key) => _parse(_fields[key]!.text)!;
    try {
      final p = SafetyDepthInput(foreDraft: v('fore'),aftDraft: v('aft'),displacementMT: v('displacement'),
        waterDensity: v('waterDensity'),chartedDepth: v('depth'),speedThroughWater: v('speed'),
        heelDegrees: v('heel'),densityCorrection: v('density'),catzoc: _catzoc!,
        tableCb: vessel.cbMethod == tableCbMethod ? v('tableCb') : null,
        manualDepthAllowance: ['D','U'].contains(_catzoc) ? _parse(_fields['manualDepth']!.text) : null,
        depthAllowanceBasis: _fields['depthBasis']!.text.trim());
      final result = SafetyDepthResult.calculate(vessel,p);
      final snapshot = <String,dynamic>{for (final e in _fields.entries) e.key: e.value.text,
        'catzoc': _catzoc,'calculatedUTC': result.calculatedUTC.toIso8601String()};
      setState(() { _result = result; _error = null; _saving = true; });
      try { await SafetyDepthStore.saveInputs(snapshot); }
      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Result calculated, but inputs could not be saved.'))); }
      finally { if (mounted) setState(() => _saving = false); }
    } on FormatException catch (e) { setState(() { _result = null; _error = e.message; }); }
    catch (_) { setState(() { _result = null; _error = 'Check the entered values and units.'; }); }
  }
  Future<void> _export() async {
    final result = _result;
    if (result == null || _busy) return;
    final type = await showModalBottomSheet<String>(context: context,backgroundColor: _panel,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,children: [
        const Padding(padding: EdgeInsets.all(20),child: Text('Export Full Report',
          style: TextStyle(fontSize: 22,fontWeight: FontWeight.w700))),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined,color: _accent),
          title: const Text('PDF'),subtitle: const Text('Full report for viewing and printing'),
          onTap: () => Navigator.pop(context,'pdf')),
        ListTile(leading: const Icon(Icons.table_chart_outlined,color: _accent),
          title: const Text('Excel (.xlsx)'),subtitle: const Text('Inputs, formulas and calculated values'),
          onTap: () => Navigator.pop(context,'xlsx')),
        const SizedBox(height: 16),
      ])));
    if (type == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      await exportSafetyDepthReport(result,type);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Report prepared. Check your downloads or selected save location.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Report export failed. Please try again.')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }
  void _method() => showDialog<void>(context: context,builder: (context) => AlertDialog(
    title: const Text('Calculation Method'),content: const SingleChildScrollView(child: Text(
      'Max Draft = MAX(Fore Draft, Aft Draft)\n'
      'Mean Draft = (Fore Draft + Aft Draft) / 2\n'
      'Cb = (Displacement / Water Density) / (LBP × Breadth × Mean Draft), or entered from vessel tables.\n'
      'Safety Margin = 10% × Max Draft\nSquat = Cb × STW² / 50\n'
      'Heel Correction = 0.008 × Breadth × |Heel Angle in degrees|\n'
      'Density Correction = manually entered value, initially 0 m.\n'
      'ENC ZOC: A1 = 0.5 + 0.01d; A2/B = 1 + 0.02d; C = 2 + 0.05d.\n'
      'D/U require a justified manual depth allowance and its basis. Without these, assessment is incomplete.\n\n'
      'Safety Depth is the sum of Max Draft, Safety Margin, Squat, Heel Correction, '
      'Density Correction and ENC ZOC Correction.\n'
      'd is the entered charted depth. Result is rounded upward to 0.01 m.\n\n'
      'The configured squat and linear heel relations are approximations. '
      'Use them within the conditions applicable to the vessel. Mean fore/aft draught is a simple approximation. '
      'CATZOC depth accuracy is a 95% measure, not a guaranteed seabed limit. '
      'Do not add a density correction already included in the entered draughts. '
      'This calculation does not select an ECDIS contour or assess passage safety.',
      style: TextStyle(height: 1.5))),actions: [TextButton(onPressed: () => Navigator.pop(context),child: const Text('Close'))]));
  Widget _resultView(SafetyDepthResult result) => _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
    const Text('SAFETY DEPTH',style: TextStyle(color: _muted,letterSpacing: 2)),
    const SizedBox(height: 10),
    Text('${result.displayedDepth.toStringAsFixed(2)} m',style: const TextStyle(
      color: _accent,fontSize: 42,fontWeight: FontWeight.w700)),
    const Text('Rounded upward to 0.01 m',style: TextStyle(color: _muted,fontSize: 12)),
    const SizedBox(height: 20),
    for (final line in result.calculationLines.take(8)) Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(alignment: WrapAlignment.spaceBetween,spacing: 16,runSpacing: 4,children: [
        Text(line.label,style: const TextStyle(color: _muted)),
        Text('${line.value.toStringAsFixed(line.unit == '-' ? 6 : 4)} ${line.unit == '-' ? '' : line.unit}')
      ])),
    if (result.warning != null) ...[const SizedBox(height: 12),Text(result.warning!,
      style: const TextStyle(color: Colors.amber,height: 1.5))],
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: _busy ? null : _export,icon: const Icon(Icons.download_outlined),
      label: Text(_exporting ? 'Preparing Report...' : 'Export Full Report'),
      style: FilledButton.styleFrom(backgroundColor: _accent,foregroundColor: _navy,
        padding: const EdgeInsets.all(18))),
  ]));
  @override
  Widget build(BuildContext context) {
    final vessel = _vessel;
    final fore = _parse(_fields['fore']!.text), aft = _parse(_fields['aft']!.text);
    final validDrafts = fore != null && aft != null && fore > 0 && aft > 0;
    final maximum = validDrafts ? (fore! > aft! ? fore : aft) : null;
    final mean = validDrafts ? fore! / 2 + aft! / 2 : null;
    return Scaffold(backgroundColor: _navy,
      appBar: AppBar(title: const Text('Safety Depth'),actions: [
        IconButton(onPressed: _loading || _busy ? null : _settings,
          tooltip: 'Vessel Particulars',icon: const Icon(Icons.settings_outlined)),
        IconButton(onPressed: _method,tooltip: 'Calculation method',icon: const Icon(Icons.info_outline)),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: _accent))
        : _loadError != null ? Center(child: Column(mainAxisSize: MainAxisSize.min,children: [
            Text(_loadError!),TextButton(onPressed: _load,child: const Text('Retry'))]))
        : SingleChildScrollView(padding: const EdgeInsets.all(20),child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,children: [
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
              Text(vessel?.name ?? 'Vessel Particulars',style: const TextStyle(fontSize: 24,fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(vessel == null ? 'Enter vessel particulars once and save.'
                : 'LBP ${vessel.lengthBP} m • Breadth ${vessel.breadth} m\n${vessel.methodLabel}',
                style: const TextStyle(color: _muted,height: 1.6)),
              if (_reviewSettings) const Padding(padding: EdgeInsets.only(top: 12),child: Text(
                'Vessel dimensions restored from the previous version. Select the Cb method and save Vessel Particulars.',
                style: TextStyle(color: Colors.amber,height: 1.5))),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _busy ? null : _settings,icon: const Icon(Icons.settings_outlined),
                label: const Text('Vessel Particulars')),
            ])),
            if (vessel != null && !_reviewSettings) ...[
              const SizedBox(height: 24),
              const Text('Current Calculation',style: TextStyle(fontSize: 25,fontWeight: FontWeight.w700)),
              if (_restored) const Padding(padding: EdgeInsets.only(top: 8),child: Text(
                'Last calculated inputs restored. Review for the current condition.',style: TextStyle(color: _muted))),
              const SizedBox(height: 20),
              Form(key: _form,child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
                _number('fore','Fore Draft (m)',positive: true),
                _number('aft','Aft Draft (m)',positive: true),
                _derived('Max Draft (m) — automatic',maximum),
                _derived('Mean Draft (m) — automatic',mean),
                _number('displacement','Displacement (t)',positive: true),
                _number('waterDensity','Water Density (t/m³)',positive: true),
                if (vessel.cbMethod == tableCbMethod) _number('tableCb','Cb from Vessel Tables',positive: true),
                _number('depth','Min Depth from Chart (m)',positive: true),
                _number('speed','Vessel Speed — STW (kts)'),
                _number('heel','Heel Angle (°)',signed: true),
                _number('density','Density Correction (m)'),
                DropdownButtonFormField<String>(value: _catzoc,isExpanded: true,
                  decoration: _decoration('CATZOC'),items: ['A1','A2','B','C','D','U'].map((c) =>
                    DropdownMenuItem(value: c,child: Text(c))).toList(),
                  onChanged: _busy ? null : (v) => setState(() { _catzoc = v; _result = null; _error = null; }),
                  validator: (v) => v == null ? 'Select CATZOC.' : null),
                if (['D','U'].contains(_catzoc)) const Padding(padding: EdgeInsets.only(top: 14),child: Text(
                  'D/U: assessment incomplete without a justified manual depth allowance. D is worse than C; U is unassessed. '
                  'No automatic category C substitution is made.',style: TextStyle(color: Colors.amber,height: 1.5))),
                if (['D','U'].contains(_catzoc)) ...[
                  const SizedBox(height: 18),
                  _number('manualDepth','Manual Depth Allowance (m)'),
                  TextFormField(controller: _fields['depthBasis'],enabled: !_busy,
                    decoration: _decoration('Basis for Manual Allowance',help: 'Record the survey, port advice or assessment supporting the allowance.'),
                    onChanged: (_) => _invalidate(),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Assessment incomplete: enter the basis.' : null),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(onPressed: _busy ? null : _calculate,
                  style: FilledButton.styleFrom(backgroundColor: _accent,foregroundColor: _navy,
                    padding: const EdgeInsets.all(20)),icon: const Icon(Icons.calculate_outlined),
                  label: Text(_saving ? 'Saving Inputs...' : 'Calculate Safety Depth')),
              ])),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 16),child: Text(_error!,
                style: const TextStyle(color: Color(0xFFFFB4AB)))),
              if (_result != null) ...[const SizedBox(height: 24),_resultView(_result!)],
            ],
          ])),
        )),
    );
  }
}

class _VesselParticularsScreen extends StatefulWidget {
  final VesselSafetySettings? settings;
  const _VesselParticularsScreen({this.settings});
  @override
  State<_VesselParticularsScreen> createState() => _VesselParticularsScreenState();
}
class _VesselParticularsScreenState extends State<_VesselParticularsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _length, _breadth;
  String _method = calculateCbMethod;
  bool _saving = false;
  @override
  void initState() {
    super.initState(); final p = widget.settings;
    _name = TextEditingController(text: p?.name ?? '');
    _length = TextEditingController(text: p?.lengthBP.toString() ?? '');
    _breadth = TextEditingController(text: p?.breadth.toString() ?? '');
    _method = p?.cbMethod ?? calculateCbMethod;
  }
  @override
  void dispose() { _name.dispose(); _length.dispose(); _breadth.dispose(); super.dispose(); }
  Widget _field(TextEditingController c,String label,{bool numeric = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 20),child: TextFormField(controller: c,enabled: !_saving,
      decoration: _decoration(label),keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: (v) => numeric ? (_parse(v) == null || _parse(v)! <= 0 ? 'Enter a positive finite number.' : null)
        : ((v ?? '').trim().isEmpty ? 'Enter vessel name.' : null)));
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = VesselSafetySettings(name: _name.text.trim(),lengthBP: _parse(_length.text)!,
      breadth: _parse(_breadth.text)!,cbMethod: _method);
    setState(() => _saving = true);
    try {
      await SafetyDepthStore.saveProfile(p);
      if (mounted) {
        setState(() => _saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context,p);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vessel particulars could not be saved.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving,child: Scaffold(backgroundColor: _navy,
    appBar: AppBar(title: const Text('Vessel Particulars')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20),child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),child: Form(key: _form,child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        const Text('Saved on This Device',style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        _field(_name,'Vessel Name'),_field(_length,'LBP (m)',numeric: true),_field(_breadth,'Breadth (m)',numeric: true),
        DropdownButtonFormField<String>(value: _method,isExpanded: true,decoration: _decoration('Cb Method'),
          items: const [DropdownMenuItem(value: calculateCbMethod,child: Text('Calculate Cb')),
            DropdownMenuItem(value: tableCbMethod,child: Text('Enter Cb from Tables'))],
          onChanged: _saving ? null : (v) { if (v != null) setState(() => _method = v); }),
        const SizedBox(height: 26),
        FilledButton.icon(onPressed: _saving ? null : _save,icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save Vessel Particulars'),
          style: FilledButton.styleFrom(backgroundColor: _accent,foregroundColor: _navy,
            padding: const EdgeInsets.all(20))),
      ])),
    ))),
  ));
}
