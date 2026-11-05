import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart' as fs;

// Module-local theme matches Vessel Assistant.
const navy = Color(0xFF081522);
const panel = Color(0xFF112437);
const accent = Color(0xFF4DDAC6);
const muted = Color(0xFF9BB0C3);
const outline = Color(0xFF294155);

Future<void> _pendingInputWrites = Future<void>.value();

const _tanksKey = 'deck_tanks_v1';

double? parseTankNumber(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

class FuelTank {
  final String id;
  final String name;
  final String fuelType;
  final double? capacityM3;
  final double? volumeM3;
  final double? densityMtPerM3;
  final double? legacyMaximumMass;
  final double? legacyFuelMass;
  final String updatedAt;

  const FuelTank({
    required this.id,
    required this.name,
    required this.fuelType,
    required double capacityM3,
    required double volumeM3,
    required double densityMtPerM3,
    required this.updatedAt,
  }) : capacityM3 = capacityM3,
       volumeM3 = volumeM3,
       densityMtPerM3 = densityMtPerM3,
       legacyMaximumMass = null,
       legacyFuelMass = null;

  const FuelTank.legacy({
    required this.id,
    required this.name,
    required this.fuelType,
    required double maximumMass,
    required double currentMass,
    required this.updatedAt,
  }) : capacityM3 = null,
       volumeM3 = null,
       densityMtPerM3 = null,
       legacyMaximumMass = maximumMass,
       legacyFuelMass = currentMass;

  bool get isLegacy => densityMtPerM3 == null;
  double get massMT => isLegacy ? legacyFuelMass! : volumeM3! * densityMtPerM3!;
  double get fillPercentage => isLegacy ? 0 : volumeM3! / capacityM3! * 100;

  Map<String, dynamic> toJson() {
    if (isLegacy) {
      return {
        'id': id, 'name': name, 'fuelType': fuelType,
        'maximumFuelMass': legacyMaximumMass,
        'fuelOnBoard': legacyFuelMass, 'updatedAt': updatedAt,
      };
    }
    return {
      'schemaVersion': 2,
      'id': id, 'name': name, 'fuelType': fuelType,
      'capacityM3': capacityM3, 'volumeM3': volumeM3,
      'densityMtPerM3': densityMtPerM3, 'updatedAt': updatedAt,
    };
  }

  factory FuelTank.fromJson(Map<String, dynamic> value) {
    final id = value['id'] as String;
    final name = value['name'] as String;
    final type = value['fuelType'] as String;
    final updated = value['updatedAt'] as String;
    double number(String key) {
      final result = (value[key] as num).toDouble();
      if (!result.isFinite) throw FormatException('Invalid $key');
      return result;
    }
    double capacity;
    double volume;
    double density;
    if (value.containsKey('capacityM3')) {
      capacity = number('capacityM3');
      volume = number('volumeM3');
      density = number('densityMtPerM3');
    } else {
      final maximum = number('maximumFuelMass');
      final current = number('fuelOnBoard');
      if (maximum <= 0 || current < 0 || current > maximum) {
        throw const FormatException('Invalid legacy tank mass');
      }
      if (value['densityMtPerM3'] == null) {
        return FuelTank.legacy(id: id, name: name, fuelType: type,
          maximumMass: maximum, currentMass: current, updatedAt: updated);
      }
      density = number('densityMtPerM3');
      if (density <= 0) throw const FormatException('Invalid density');
      capacity = maximum / density;
      volume = current / density;
    }
    if (!capacity.isFinite || !volume.isFinite || capacity <= 0 ||
        volume < 0 || volume > capacity || density <= 0 ||
        !(capacity * density).isFinite || capacity * density <= 0 ||
        !(volume * density).isFinite || (volume > 0 && volume * density <= 0)) {
      throw const FormatException('Invalid tank volume or density');
    }
    return FuelTank(id: id, name: name, fuelType: type,
      capacityM3: capacity, volumeM3: volume,
      densityMtPerM3: density, updatedAt: updated);
  }
}

List<FuelTank> decodeTanks(String? raw) {
  if (raw == null) return [];
  final data = jsonDecode(raw) as List;
  return data.map((item) => FuelTank.fromJson(
    Map<String, dynamic>.from(item as Map),
  )).toList();
}

Future<void> persistTanks(List<FuelTank> tanks) {
  final text = jsonEncode(tanks.map((tank) => tank.toJson()).toList());
  final operation = _pendingInputWrites.then((_) async {
    await SharedPreferencesAsync().setString(_tanksKey, text);
  });
  // Keep the shared queue usable if this particular operation fails.
  _pendingInputWrites = operation.then<void>(
    (_) {}, onError: (Object error, StackTrace stackTrace) {},
  );
  return operation;
}

class FuelTanksScreen extends StatefulWidget {
  const FuelTanksScreen({super.key});
  @override
  State<FuelTanksScreen> createState() => _FuelTanksScreenState();
}

class _FuelTanksScreenState extends State<FuelTanksScreen> {
  List<FuelTank> _tanks = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _pendingInputWrites;
      final tanks = decodeTanks(await SharedPreferencesAsync().getString(_tanksKey));
      if (!mounted) return;
      setState(() { _tanks = tanks; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tanks could not be loaded. Please retry.';
        _loading = false;
      });
    }
  }

  Future<bool> _commit(List<FuelTank> next) async {
    setState(() => _saving = true);
    try {
      await persistTanks(next);
      if (!mounted) return false;
      setState(() => _tanks = next);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Changes could not be saved. Please try again.'),
      ));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([FuelTank? tank]) async {
    final result = await showDialog<FuelTank>(
      context: context,
      builder: (_) => TankEditorDialog(tank: tank, existingTanks: _tanks),
    );
    if (result == null || !mounted) return;
    final next = [..._tanks];
    final index = next.indexWhere((item) => item.id == result.id);
    if (index < 0) { next.add(result); } else { next[index] = result; }
    final saved = await _commit(next);
    if (!saved || !mounted) return;
    if (result.fillPercentage >= 100) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: panel,
          icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.redAccent, size: 48),
          title: const Text('Tank Full'),
          content: Text('${result.name} is at 100% of the specified '
            'tank capacity by volume.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Acknowledge'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _delete(FuelTank tank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Delete tank?'),
        content: Text('Delete "${tank.name}" and its current inventory data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Tank')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _commit(_tanks.where((item) => item.id != tank.id).toList());
  }

  Widget _tankCard(FuelTank tank) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tank.fillPercentage >= 100 ? Colors.redAccent : outline,
          width: tank.fillPercentage >= 100 ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tank.name, style: const TextStyle(
            fontSize: 21, fontWeight: FontWeight.w700,
          ))),
          PopupMenuButton<String>(
            enabled: !_saving,
            tooltip: 'Tank settings',
            onSelected: (value) {
              if (value == 'edit') { _edit(tank); } else { _delete(tank); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Tank')),
              PopupMenuItem(value: 'delete', child: Text('Delete Tank')),
            ],
          ),
        ]),
        Text(tank.fuelType, style: const TextStyle(color: muted)),
        const SizedBox(height: 20),
        if (tank.isLegacy)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: navy,
              borderRadius: BorderRadius.circular(16)),
            child: const Column(children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 38),
              SizedBox(height: 12),
              Text('Volume and density required',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amber)),
            ]),
          )
        else
          TankGauge(percentage: tank.fillPercentage),
        const SizedBox(height: 20),
        if (!tank.isLegacy) ...[
          Text('${tank.volumeM3!.toStringAsFixed(2)} m³ on board',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Capacity: ${tank.capacityM3!.toStringAsFixed(2)} m³',
            style: const TextStyle(color: muted)),
          const SizedBox(height: 6),
          Text('Density: ${tank.densityMtPerM3!.toStringAsFixed(4)} MT/m³',
            style: const TextStyle(color: muted)),
        ],
        const SizedBox(height: 10),
        Text('${tank.massMT.toStringAsFixed(3)} MT${tank.isLegacy ? ' (previous entry)' : ''}',
          style: const TextStyle(color: accent, fontSize: 20,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _edit(tank),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Update Tank'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(
      child: CircularProgressIndicator(color: accent),
    ));
    if (_error != null) return Scaffold(body: Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(_error!), const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Retry'))],
    )));
    final total = _tanks.fold<double>(0, (sum, tank) => sum + tank.massMT);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Tanks', style: TextStyle(
              fontSize: 34, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 10),
            const Text(
              'Filling is based on liquid volume divided by tank capacity. '
              'The diagram does not represent actual liquid height.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: _saving ? null : () => _edit(),
                icon: const Icon(Icons.add), label: const Text('Add Tank'),
                style: FilledButton.styleFrom(backgroundColor: accent,
                  foregroundColor: navy),
              ),
              TankExcelButton(enabled: !_saving),
            ]),
            const SizedBox(height: 24),
            Text('Total Water on Board: ${total.toStringAsFixed(2)} MT',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            Text('${_tanks.length} tanks', style: const TextStyle(color: muted)),
            Text('Recorded volume: ${_tanks.fold<double>(0, (sum, tank) => sum + (tank.volumeM3 ?? 0)).toStringAsFixed(2)} m³',
              style: const TextStyle(color: muted)),
            if (_tanks.any((tank) => tank.isLegacy))
              const Padding(padding: EdgeInsets.only(top: 10), child: Text(
                'Some tanks contain previous mass-only entries. '
                'Their masses are included above; their volumes are not yet known. '
                'Select Update Tank to enter capacity, volume and density.',
                style: TextStyle(color: Colors.amber, height: 1.5),
              )),
            const SizedBox(height: 24),
            if (_saving) const LinearProgressIndicator(color: accent),
            if (_tanks.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Text(
                'No tanks yet. Select Add Tank to create your first tank.',
                textAlign: TextAlign.center, style: TextStyle(color: muted),
              ))
            else
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980 ? 3
                    : constraints.maxWidth >= 640 ? 2 : 1;
                final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
                return Wrap(spacing: 18, runSpacing: 18, children: [
                  for (final tank in _tanks)
                    SizedBox(width: width, child: _tankCard(tank)),
                ]);
              }),
          ]),
        )),
      ),
    );
  }
}

// This is a schematic percentage gauge, not a calibrated tank geometry.
class TankGauge extends StatelessWidget {
  final double percentage;
  const TankGauge({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final fraction = (percentage / 100).clamp(0.0, 1.0).toDouble();
    final isFull = percentage >= 100;
    final tankColor = isFull ? Colors.redAccent : accent;
    return Semantics(
      label: '${percentage.toStringAsFixed(1)} percent of tank capacity by volume',
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tankColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: navy),
            Align(alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1, heightFactor: fraction,
                child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: isFull
                        ? const [Color(0xFFEF5350), Color(0xFF991B1B)]
                        : const [Color(0xFF31B6A5), Color(0xFF156D75)],
                  ),
                )),
              )),
            for (final y in [-0.5, 0.0, 0.5])
              Align(alignment: Alignment(0, y), child: const Divider(
                color: Color(0x558CB4C8), thickness: 1, height: 1,
              )),
            Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: navy,
                borderRadius: BorderRadius.circular(12)),
              child: Text('${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );
  }
}

class TankEditorDialog extends StatefulWidget {
  final FuelTank? tank;
  final List<FuelTank> existingTanks;
  const TankEditorDialog({super.key, this.tank, required this.existingTanks});
  @override
  State<TankEditorDialog> createState() => _TankEditorDialogState();
}

class _TankEditorDialogState extends State<TankEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _type;
  late final TextEditingController _capacity;
  late final TextEditingController _volume;
  late final TextEditingController _density;

  @override
  void initState() {
    super.initState();
    final tank = widget.tank;
    _name = TextEditingController(text: tank?.name ?? '');
    _type = TextEditingController(text: tank?.fuelType ?? '');
    _capacity = TextEditingController(text: tank?.capacityM3?.toString() ?? '');
    _volume = TextEditingController(text: tank == null ? '0' : tank.volumeM3?.toString() ?? '');
    _density = TextEditingController(
      text: tank == null
          ? '1.025'
          : tank.densityMtPerM3?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose(); _type.dispose(); _capacity.dispose();
    _volume.dispose(); _density.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
      String? Function(String?) validator, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, errorMaxLines: 2),
        onChanged: (_) => setState(() {}),
        validator: validator,
      ),
    );
  }

  String? _positive(String? text) {
    final value = parseTankNumber(text ?? '');
    return value == null || value <= 0
        ? 'Enter a finite number greater than zero.' : null;
  }

  void _convertPreviousMass() {
    final density = parseTankNumber(_density.text);
    if (density == null || density <= 0) {
      _form.currentState!.validate();
      return;
    }
    final volume = widget.tank!.massMT / density;
    if (!volume.isFinite || (widget.tank!.massMT > 0 && volume <= 0)) return;
    setState(() => _volume.text = volume.toString());
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final capacity = parseTankNumber(_capacity.text)!;
    final volume = parseTankNumber(_volume.text)!;
    final density = parseTankNumber(_density.text)!;
    if (!(capacity * density).isFinite || capacity * density <= 0 ||
        !(volume * density).isFinite || (volume > 0 && volume * density <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Values exceed the calculation range.'),
      ));
      return;
    }
    final now = DateTime.now().toUtc();
    Navigator.pop(context, FuelTank(
      id: widget.tank?.id ?? 'tank_${now.microsecondsSinceEpoch}',
      name: _name.text.trim(), fuelType: _type.text.trim(),
      capacityM3: capacity, volumeM3: volume, densityMtPerM3: density,
      updatedAt: now.toIso8601String(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final volume = parseTankNumber(_volume.text);
    final density = parseTankNumber(_density.text);
    final capacity = parseTankNumber(_capacity.text);
    final mass = volume != null && volume >= 0 && density != null && density > 0
        ? volume * density : null;
    final fill = volume != null && volume >= 0 && capacity != null && capacity > 0
        ? volume / capacity * 100 : null;
    final legacy = widget.tank?.isLegacy ?? false;
    return AlertDialog(
      backgroundColor: panel,
      title: Text(widget.tank == null ? 'Add Tank' : 'Edit Tank'),
      content: SizedBox(width: 460, child: SingleChildScrollView(
        child: Form(key: _form, child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (legacy) ...[
              Text('Previous mass: ${widget.tank!.massMT.toStringAsFixed(3)} MT. '
                'Enter the actual tank capacity in m³. Enter liquid volume manually '
                'or convert the previous mass after entering its corresponding density.',
                style: const TextStyle(color: muted, height: 1.5)),
              const SizedBox(height: 18),
            ],
            _field(_name, 'Tank Name', (text) {
              final name = (text ?? '').trim();
              if (name.isEmpty) return 'Enter a tank name.';
              if (widget.existingTanks.any((tank) => tank.id != widget.tank?.id &&
                  tank.name.toLowerCase() == name.toLowerCase())) {
                return 'A tank with this name already exists.';
              }
              return null;
            }),
            _field(_type, 'Contents (e.g. MGO, Ballast, Fresh Water)', (text) =>
              (text ?? '').trim().isEmpty ? 'Enter tank contents or type.' : null),
            _field(_capacity, 'Tank Capacity (m³)', _positive, numeric: true),
            _field(_volume, 'Liquid Volume (m³)', (text) {
              final value = parseTankNumber(text ?? '');
              final limit = parseTankNumber(_capacity.text);
              if (value == null || value < 0) return 'Enter a number of zero or greater.';
              if (limit != null && value > limit) return 'Volume cannot exceed tank capacity.';
              return null;
            }, numeric: true),
            _field(_density, 'Density (MT/m³)', _positive, numeric: true),
            if (legacy) ...[
              OutlinedButton.icon(
                onPressed: _convertPreviousMass,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Convert Previous Mass to m³'),
              ),
              const SizedBox(height: 16),
            ],
            const Text('The default 1.025 MT/m³ is an editable seawater preset. '
              'Use the actual liquid density at the volume temperature. No automatic temperature correction is applied.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 18),
            Text(mass != null && mass.isFinite
                ? 'Calculated Mass: ${mass.toStringAsFixed(3)} MT' : 'Calculated Mass: —',
              style: const TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(fill != null && fill.isFinite
                ? 'Filling: ${fill.toStringAsFixed(1)}%' : 'Filling: —',
              style: const TextStyle(color: muted)),
          ],
        )),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save Tank')),
      ],
    );
  }
}

xl.CellValue? _excelCell(Object? value) {
  if (value == null) return null;
  if (value is int) return xl.IntCellValue(value);
  if (value is double) {
    return value.isFinite ? xl.DoubleCellValue(value) : null;
  }
  // User text stays text, even if a tank name starts with '='.
  return xl.TextCellValue(value.toString());
}

void _excelRow(xl.Sheet sheet, List<Object?> values) {
  sheet.appendRow(values.map(_excelCell).toList());
}

xl.Sheet _excelSheet(xl.Excel book, String name, List<String> headings) {
  final sheet = book[name];
  _excelRow(sheet, headings);
  for (var column = 0; column < headings.length; column++) {
    sheet.setColumnWidth(column, column == 0 ? 30 : 24);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        .cellStyle = xl.CellStyle(bold: true, textWrapping: xl.TextWrapping.WrapText);
  }
  return sheet;
}


Uint8List buildTankWorkbook(List<FuelTank> tanks, DateTime now) {
  final book = xl.Excel.createExcel();
  final info = _excelSheet(book, 'Report Info', ['Item', 'Details']);
  book.setDefaultSheet('Report Info');
  book.delete('Sheet1');
  info.setColumnWidth(1, 95);
  _excelRow(info, ['Application', 'Vessel Assistant - Deck Tanks']);
  _excelRow(info, ['Exported at (UTC)', now.toUtc().toIso8601String()]);
  _excelRow(info, ['Scope', 'Current saved tank inventory, not a historical log.']);
  _excelRow(info, ['Mass', 'Liquid volume (m³) x corresponding density (MT/m³).']);
  _excelRow(info, ['Filling', 'Liquid volume / tank capacity x 100. Schematic, not actual liquid height.']);
  _excelRow(info, ['Temperature', 'Density must correspond to the entered volume temperature. No automatic correction.']);

  final sheet = _excelSheet(book, 'Tanks', [
    'Tank Name', 'Contents', 'Capacity (m³)', 'Volume (m³)',
    'Density (MT/m³)', 'Mass (MT)', 'Filling (%)', 'Last Updated (UTC)',
  ]);
  sheet.setColumnWidth(7, 30);
  for (final tank in tanks) {
    _excelRow(sheet, [tank.name, tank.fuelType, tank.capacityM3,
      tank.volumeM3, tank.densityMtPerM3, tank.massMT,
      tank.isLegacy ? null : tank.fillPercentage, tank.updatedAt]);
  }
  _excelRow(sheet, ['TOTAL', null,
    tanks.fold<double>(0, (sum, tank) => sum + (tank.capacityM3 ?? 0)),
    tanks.fold<double>(0, (sum, tank) => sum + (tank.volumeM3 ?? 0)),
    null, tanks.fold<double>(0, (sum, tank) => sum + tank.massMT), null, null]);
  final bytes = book.encode();
  if (bytes == null) throw StateError('Excel encoding failed');
  return Uint8List.fromList(bytes);
}

class TankExcelButton extends StatefulWidget {
  final bool enabled;
  const TankExcelButton({super.key, this.enabled = true});
  @override
  State<TankExcelButton> createState() => _TankExcelButtonState();
}

class _TankExcelButtonState extends State<TankExcelButton> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final snapshot = _pendingInputWrites.then((_) async {
        return decodeTanks(await SharedPreferencesAsync().getString(_tanksKey));
      });
      _pendingInputWrites = snapshot.then<void>(
        (_) {}, onError: (Object error, StackTrace stackTrace) {},
      );
      final tanks = await snapshot;
      final now = DateTime.now().toUtc();
      final bytes = buildTankWorkbook(tanks, now);
      final name = 'deck_tanks_${now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}';
      const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      if (kIsWeb) {
        await fs.FileSaver.instance.saveFile(
          name: name, bytes: bytes, fileExtension: 'xlsx',
          mimeType: fs.MimeType.custom, customMimeType: mime,
        );
      } else {
        final result = await fs.FileSaver.instance.saveAs(
          name: name, bytes: bytes, fileExtension: 'xlsx',
          mimeType: fs.MimeType.custom, customMimeType: mime,
        );
        if (result == null) return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        kIsWeb ? 'Excel download requested. Check your browser downloads.'
            : 'Excel report saved.',
      )));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Excel export failed. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy || !widget.enabled ? null : _export,
    icon: _busy ? const SizedBox(width: 18, height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: accent))
        : const Icon(Icons.download_outlined),
    label: Text(_busy ? 'Preparing Excel...' : 'Export Tanks to Excel'),
  );
}
