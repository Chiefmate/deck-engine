import 'package:flutter/material.dart';

class BallastSequenceScreen extends StatefulWidget {
  const BallastSequenceScreen({super.key, required this.start});

  final DateTime start;

  @override
  State<BallastSequenceScreen> createState() => _BallastSequenceScreenState();
}

class _Operation {
  String name = '';
  String volume = '';
  String rate = '';
  bool parallel = false;
}

class _BallastSequenceScreenState extends State<BallastSequenceScreen> {
  final _form = GlobalKey<FormState>();
  final _operations = [_Operation()];
  List<({String name, DateTime start, DateTime finish})>? _schedule;
  DateTime? _finish;
  String? _error;

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _change(VoidCallback change) {
    setState(() {
      change();
      _schedule = null;
      _finish = null;
      _error = null;
    });
  }

  void _calculate() {
    if (!_form.currentState!.validate()) return;
    final schedule = <({String name, DateTime start, DateTime finish})>[];
    var stageStart = widget.start;
    var stageFinish = stageStart;
    for (final (index, operation) in _operations.indexed) {
      if (index > 0 && !operation.parallel) stageStart = stageFinish;
      final seconds =
          _number(operation.volume)! / _number(operation.rate)! * 3600;
      if (!seconds.isFinite || seconds > 60000000000) {
        setState(
          () =>
              _error = 'Operation ${index + 1} exceeds the calculation range.',
        );
        return;
      }
      final finish = stageStart.add(Duration(seconds: seconds.ceil()));
      if (finish.isAfter(stageFinish)) stageFinish = finish;
      schedule.add((
        name: operation.name.trim().isEmpty
            ? 'Operation ${index + 1}'
            : operation.name.trim(),
        start: stageStart,
        finish: finish,
      ));
    }
    setState(() {
      _schedule = schedule;
      _finish = stageFinish;
      _error = null;
    });
  }

  String _utc(DateTime value) =>
      '${value.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19)} UTC';

  Widget _numericField(
    String label,
    String unit,
    ValueChanged<String> onChanged,
  ) {
    return TextFormField(
      decoration: InputDecoration(labelText: label, suffixText: unit),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => _change(() => onChanged(value)),
      validator: (value) {
        final number = _number(value ?? '');
        return number == null || !number.isFinite || number <= 0
            ? 'Enter a number greater than zero.'
            : null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    return Scaffold(
      appBar: AppBar(title: const Text('Ballast Sequence')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Plan start: ${_utc(widget.start)}'),
                const SizedBox(height: 8),
                const Text(
                  'Set the start time in Ballast Time. Parallel operations share a start time; '
                  'the next stage waits for all of them. Enter the effective rate for each '
                  'operation when running together. Use the ship’s approved sequence.',
                ),
                for (final (index, operation) in _operations.indexed)
                  Card(
                    key: ObjectKey(operation),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Operation ${index + 1}'),
                              if (_operations.length > 1)
                                IconButton(
                                  tooltip: 'Remove operation',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _change(() {
                                    final startsStage = !operation.parallel;
                                    _operations.removeAt(index);
                                    if (startsStage &&
                                        index < _operations.length) {
                                      _operations[index].parallel = false;
                                    }
                                  }),
                                ),
                            ],
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Operation name (optional)',
                            ),
                            onChanged: (value) =>
                                _change(() => operation.name = value),
                          ),
                          _numericField(
                            'Volume to pump',
                            'm³',
                            (value) => operation.volume = value,
                          ),
                          _numericField(
                            'Effective pump rate',
                            'm³/h',
                            (value) => operation.rate = value,
                          ),
                          if (index > 0)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Start with previous operation',
                              ),
                              value: operation.parallel,
                              onChanged: (value) => _change(
                                () => operation.parallel = value ?? false,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          _change(() => _operations.add(_Operation())),
                      child: const Text('Add operation'),
                    ),
                    FilledButton(
                      onPressed: _calculate,
                      child: const Text('Calculate sequence'),
                    ),
                  ],
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (schedule != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Plan finish: ${_utc(_finish!)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final operation in schedule)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(operation.name),
                      subtitle: Text(
                        '${_utc(operation.start)} → ${_utc(operation.finish)}',
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
