import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _navy = Color(0xFF081522);
const _panel = Color(0xFF112437);
const _accent = Color(0xFF4DDAC6);
const _muted = Color(0xFF9BB0C3);
const _outline = Color(0xFF294155);
const _assetPath = 'assets/data/ports.json';

// Match common Latin diacritics without adding a package dependency.
String _foldQuery(String text) {
  var result = text.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  const groups = {
    'a': 'àáâãäåāăą', 'c': 'çćĉċč', 'd': 'ďđð',
    'e': 'èéêëēĕėęě', 'g': 'ĝğġģ', 'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı', 'j': 'ĵ', 'k': 'ķ', 'l': 'ĺļľŀł',
    'n': 'ñńņňŋ', 'o': 'òóôõöøōŏő', 'r': 'ŕŗř',
    's': 'śŝşšș', 't': 'ţťŧț', 'u': 'ùúûüũūŭůűų',
    'w': 'ŵ', 'y': 'ýÿŷ', 'z': 'źżž',
  };
  for (final group in groups.entries) {
    for (final rune in group.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), group.key);
    }
  }
  return result.replaceAll('æ', 'ae').replaceAll('œ', 'oe')
      .replaceAll('ß', 'ss').replaceAll('þ', 'th');
}

class _Port {
  final String code;
  final String name;
  final String country;
  final String countryCode;
  final String subdivision;
  final String functions;
  final String status;
  final String coordinates;
  final String updated;
  final String search;
  final List<String> aliases;

  _Port.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String,
        name = json['name'] as String,
        country = json['country'] as String,
        countryCode = json['countryCode'] as String,
        subdivision = json['subdivision'] as String,
        functions = json['functions'] as String,
        status = json['status'] as String,
        coordinates = json['coordinates'] as String,
        updated = json['updatedYYMM'] as String,
        aliases = List<String>.from(json['aliases'] as List),
        search = '${json['search']} ${json['name']} ${json['country']}'
            .toLowerCase();
}

class _PortDatabase {
  final Map<String, dynamic> metadata;
  final List<_Port> ports;
  _PortDatabase(this.metadata, this.ports);
}

class PortCodesScreen extends StatefulWidget {
  const PortCodesScreen({super.key});
  @override
  State<PortCodesScreen> createState() => _PortCodesScreenState();
}

class _PortCodesScreenState extends State<PortCodesScreen> {
  static _PortDatabase? _cachedDatabase;
  final _query = TextEditingController();
  Timer? _debounce;
  _PortDatabase? _database;
  List<_Port> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      var database = _cachedDatabase;
      if (database == null) {
        final text = await rootBundle.loadString(_assetPath);
        final json = jsonDecode(text) as Map<String, dynamic>;
        final ports = (json['ports'] as List).map((item) =>
          _Port.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        database = _PortDatabase(
          Map<String, dynamic>.from(json['meta'] as Map), ports,
        );
        _cachedDatabase = database;
      }
      if (!mounted) return;
      setState(() { _database = database; _loading = false; });
      _search();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Port data could not be loaded. Check that '
            'assets/data/ports.json is included in pubspec.yaml.';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    // Clear stale results immediately while waiting for the next search.
    setState(() => _matches = []);
    _debounce = Timer(const Duration(milliseconds: 180), _search);
  }

  void _search() {
    if (!mounted) return;
    final query = _foldQuery(_query.text.trim());
    if (query.length < 2 || _database == null) {
      setState(() => _matches = []);
      return;
    }
    final compactCode = query.replaceAll(RegExp(r'[\s-]+'), '').toUpperCase();
    final tokens = query.split(RegExp(r'[\s-]+')).where((t) => t.isNotEmpty).toList();
    final matches = _database!.ports.where((port) =>
      port.code == compactCode || tokens.every(port.search.contains)).toList();
    int rank(_Port port) {
      if (port.code == compactCode) return 0;
      if (port.code.startsWith(compactCode)) return 1;
      if (port.name.toLowerCase() == query) return 2;
      if (port.name.toLowerCase().startsWith(query)) return 3;
      return 4;
    }
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.code.compareTo(b.code);
    });
    setState(() => _matches = matches);
  }

  Future<void> _copy(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$code copied')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copy failed. Open the port details to select the code.'),
      ));
    }
  }

  void _showInfo() {
    final meta = _database?.metadata;
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Port Database'),
      content: SingleChildScrollView(child: SelectableText(
        'Source: UNECE / UN/CEFACT UN/LOCODE\n'
        'Edition: ${meta?['edition'] ?? 'Pre-Release'}\n'
        'Source updated: ${meta?['sourceUpdated'] ?? '2026-10-29'}\n'
        'Port entries: ${meta?['count'] ?? '—'}\n\n'
        'Includes locations with port function 1. Entries marked for deletion '
        'are excluded and duplicate codes are merged.\n\n'
        'This is a bundled snapshot, not a live directory. '
        'The pre-release can change before the next official release.\n\n'
        'Coordinates, where present, are location references at degree/minute '
        'precision; they are not berth or pilot boarding positions.\n\n'
        'License: CC BY 4.0\n'
        'https://unlocode.unece.org/publications/',
        style: const TextStyle(color: _muted, height: 1.5),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'))],
    ));
  }

  void _details(_Port port) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(port.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SelectableText(port.code, style: const TextStyle(
              color: _accent, fontSize: 30, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            SelectableText(
              'Country: ${port.country} (${port.countryCode})\n'
              'Subdivision: ${port.subdivision.isEmpty ? 'Not listed' : port.subdivision}\n'
              'Function: ${port.functions}\n'
              'UN/LOCODE status: ${port.status.isEmpty ? 'Not listed' : port.status}\n'
              'Original coordinates: ${port.coordinates.isEmpty ? 'Not listed' : port.coordinates}\n'
              'Entry date (YYMM): ${port.updated.isEmpty ? 'Not listed' : port.updated}',
              style: const TextStyle(color: _muted, height: 1.8),
            ),
            if (port.aliases.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Other listed names: ${port.aliases.join(', ')}',
                style: const TextStyle(color: _muted, height: 1.5)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: () => _copy(port.code),
              icon: const Icon(Icons.copy_outlined), label: const Text('Copy UN/LOCODE'),
              style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: _navy)),
            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Close')),
          ],
        ),
      )),
    );
  }

  Widget _results() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _accent));
    if (_error != null) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]),
    ));
    if (_query.text.trim().length < 2) return const Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.travel_explore, color: _accent, size: 48),
        SizedBox(height: 16),
        Text('Find a port', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        SizedBox(height: 10),
        Text('Enter at least 2 characters.\nTry Rotterdam, NLRTM or NL RTM.',
          textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.6)),
      ]),
    ));
    if (_matches.isEmpty) return const Center(child: Text(
      'No matching ports found.', style: TextStyle(color: _muted),
    ));
    final shown = _matches.length > 200 ? 200 : _matches.length;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: shown,
      itemBuilder: (context, index) {
        final port = _matches[index];
        return Card(
          color: _panel,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _outline)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            title: Text(port.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('${port.code}  •  ${port.country}',
                style: const TextStyle(color: _muted))),
            trailing: IconButton(onPressed: () => _copy(port.code),
              tooltip: 'Copy ${port.code}', icon: const Icon(Icons.copy_outlined, color: _accent)),
            onTap: () => _details(port),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _database?.ports.length;
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(title: const Text('Port Codes'), actions: [
        IconButton(onPressed: _showInfo, tooltip: 'Database information',
          icon: const Icon(Icons.info_outline)),
      ]),
      body: SafeArea(top: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: TextField(
            controller: _query,
            enabled: !_loading && _error == null,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) { _debounce?.cancel(); _search(); },
            decoration: InputDecoration(
              hintText: 'Port name, UN/LOCODE or country',
              prefixIcon: const Icon(Icons.search, color: _accent),
              suffixIcon: _query.text.isEmpty ? null : IconButton(
                onPressed: () { _query.clear(); _debounce?.cancel(); _search(); },
                tooltip: 'Clear search', icon: const Icon(Icons.close)),
              filled: true, fillColor: _panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(alignment: Alignment.centerLeft,
            child: Text(_query.text.trim().length >= 2 && !_loading
                ? '${_matches.length} matches${_matches.length > 200 ? ' • Showing first 200; refine your search' : ''}'
                : '${total ?? '…'} port entries • UN/LOCODE Pre-Release 2026-10-29',
              style: const TextStyle(color: _muted, fontSize: 12)),
          ),
        ),
        Expanded(child: _results()),
      ])),
    );
  }
}
