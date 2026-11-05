import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeckOrganizerScreen extends StatefulWidget {
  const DeckOrganizerScreen({super.key});

  @override
  State<DeckOrganizerScreen> createState() => _DeckOrganizerScreenState();
}

class _DeckOrganizerScreenState extends State<DeckOrganizerScreen>
    with WidgetsBindingObserver {
  static const _storageKey = 'deck_organizer_records_v1';
  final _prefs = SharedPreferencesAsync();
  List<Map<String, dynamic>>? _records;
  String? _loadError;
  String _query = '';
  int _tab = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final raw = await _prefs.getString(_storageKey);
      final records = List<Map<String, dynamic>>.from(
        jsonDecode(raw ?? '[]') as List,
      );
      if (mounted) setState(() => _records = records);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load saved records.');
    }
  }

  Future<void> _save(List<Map<String, dynamic>> records) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _prefs.setString(_storageKey, jsonEncode(records));
      if (mounted) setState(() => _records = records);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _due(Map<String, dynamic> record) {
    final expiry = DateTime.tryParse(record['expiry'] as String? ?? '');
    if (expiry == null) return false;
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final expiryDay = DateTime.utc(expiry.year, expiry.month, expiry.day);
    return expiryDay.difference(today).inDays <= (record['lead'] as int? ?? 30);
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordEditor(
        record: record,
        document: record?['document'] as bool? ?? _tab != 0,
      ),
    );
    if (!mounted || result == null) return;
    final next = [..._records!];
    if (record == null) {
      next.insert(0, result);
    } else {
      next[next.indexOf(record)] = result;
    }
    await _save(next);
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(record['title'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _save([..._records!]..remove(record));
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: const Text('Deck Organizer')),
      body: records == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            )
          : _buildList(records),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> records) {
    final reminders = records.where(_due).length;
    final visible =
        records.where((record) {
          if ((record['document'] == true) != (_tab != 0)) return false;
          if (_tab == 2 && !_due(record)) return false;
          return [record['title'], record['body'], record['number']].any(
            (value) => value is String && value.toLowerCase().contains(_query),
          );
        }).toList()..sort((a, b) {
          if (_tab != 0) {
            return (a['expiry'] as String).compareTo(b['expiry'] as String);
          }
          if ((a['pinned'] == true) != (b['pinned'] == true)) {
            return a['pinned'] == true ? -1 : 1;
          }
          return (b['updated'] as int).compareTo(a['updated'] as int);
        });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (index, label) in [
              'Notes',
              'Documents',
              'Reminders ($reminders)',
            ].indexed)
              ChoiceChip(
                label: Text(label),
                selected: _tab == index,
                onSelected: (_) => setState(() => _tab = index),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search notes or documents',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : () => _edit(),
            child: Text(_tab == 0 ? 'New note' : 'New document'),
          ),
        ),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No matching records.')),
          ),
        for (final record in visible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['pinned'] == true
                        ? 'Pinned · ${record['title']}'
                        : record['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (record['document'] == true)
                    Text('Expiry: ${record['expiry']}'),
                  if ((record['number'] as String? ?? '').isNotEmpty)
                    Text(record['number'] as String),
                  if ((record['body'] as String).isNotEmpty)
                    Text(
                      record['body'] as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => _edit(record),
                        child: const Text('Open / Edit'),
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => _delete(record),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({required this.record, required this.document});

  final Map<String, dynamic>? record;
  final bool document;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.record?['title'] as String?,
  );
  late final _body = TextEditingController(
    text: widget.record?['body'] as String?,
  );
  late final _number = TextEditingController(
    text: widget.record?['number'] as String?,
  );
  late String _issue = widget.record?['issue'] as String? ?? '';
  late String _expiry = widget.record?['expiry'] as String? ?? '';
  late int _lead = widget.record?['lead'] as int? ?? 30;
  late bool _pinned = widget.record?['pinned'] == true;
  String? _dateError;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool expiry}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(expiry ? _expiry : _issue) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected == null || !mounted) return;
    final value = selected.toIso8601String().split('T').first;
    setState(() {
      if (expiry) {
        _expiry = value;
      } else {
        _issue = value;
      }
      _dateError = null;
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (widget.document && (_expiry.isEmpty || _issue.compareTo(_expiry) > 0)) {
      setState(
        () => _dateError = _expiry.isEmpty
            ? 'Choose an expiry date.'
            : 'Expiry must be on or after the issue date.',
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': _title.text.trim(),
      'body': _body.text,
      'document': widget.document,
      'number': _number.text.trim(),
      'issue': _issue,
      'expiry': _expiry,
      'lead': _lead,
      'pinned': _pinned,
      'updated': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.record == null ? 'New' : 'Edit'} ${widget.document ? 'document' : 'note'}',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title.'
                  : null,
            ),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(labelText: 'Notes'),
              minLines: 2,
              maxLines: 4,
            ),
            if (widget.document) ...[
              TextFormField(
                controller: _number,
                decoration: const InputDecoration(labelText: 'Document number'),
              ),
              TextButton(
                onPressed: () => _pickDate(expiry: false),
                child: Text(
                  'Issue date: ${_issue.isEmpty ? 'Choose' : _issue}',
                ),
              ),
              TextButton(
                onPressed: () => _pickDate(expiry: true),
                child: Text(
                  'Expiry date: ${_expiry.isEmpty ? 'Choose' : _expiry}',
                ),
              ),
              if (_dateError != null)
                Text(
                  _dateError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              DropdownButtonFormField<int>(
                initialValue: _lead,
                decoration: const InputDecoration(
                  labelText: 'Remind before expiry',
                ),
                items: [
                  for (final days in [30, 14, 7, 1, 0])
                    DropdownMenuItem(
                      value: days,
                      child: Text(days == 0 ? 'On expiry date' : '$days days'),
                    ),
                ],
                onChanged: (value) => setState(() => _lead = value!),
              ),
            ] else
              CheckboxListTile(
                value: _pinned,
                title: const Text('Pin note'),
                onChanged: (value) => setState(() => _pinned = value ?? false),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}
