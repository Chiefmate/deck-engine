import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _navy = Color(0xFF081522);
const _panel = Color(0xFF112437);
const _accent = Color(0xFF4DDAC6);
const _muted = Color(0xFF9BB0C3);
const _outline = Color(0xFF294155);

class _RecordTemplate {
  final String category;
  final int number;
  final String description;
  final String day;
  final String remarks;
  const _RecordTemplate({required this.category, required this.number,
    required this.description, required this.day, required this.remarks});
}

// Original templates from worksheet "2011", plus user-requested additions.
// These are reference templates, not records of completed work.
const _templates = <_RecordTemplate>[
  _RecordTemplate(
    category: "Weekly",
    number: 1,
    description: "All Watertight doors were tested (closed and opened), visually inspected.",
    day: "Wednesday",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 2,
    description: "All F.F.E. were visually checked and found in place, in good order and condition; ready for use (SCABAs checked for leakages)",
    day: "Friday",
    remarks: "3RD OFF",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 3,
    description: "All L.S.A. were visually checked and found in place, in good order and condition; ready for use.",
    day: "Saturday",
    remarks: "3RD OFF",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 4,
    description: "FFLB Davit tested & moved fm stowed psn.; secured after that. EPA VGP inspection Inspection of Crew accomodation",
    day: "Saturday",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 5,
    description: "Public Adress & Gen. Alarm systems tested",
    day: "Saturday",
    remarks: "2ND OFF",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 6,
    description: "FFLB & RB engines started & tested",
    day: "Sunday",
    remarks: "3RD OFF with assist. of 3rd Eng.",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 7,
    description: "Bilge Alarm of C. Holds testsed; In order; Working properly EDG",
    day: "Sunday",
    remarks: "CH. OFF. with assist. of El. Eng.",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 8,
    description: "VDR self-test carried out.",
    day: "",
    remarks: "2ND OFF",
  ),
  _RecordTemplate(
    category: "Weekly",
    number: 9,
    description: "Echo sounder self-test carried out.",
    day: "",
    remarks: "2ND OFF",
  ),
  _RecordTemplate(
    category: "Monthly",
    number: 1,
    description: "Fireman's outfits, Fire Extinguishers, Fire Hydrants, Fire Hoses & Nozzles visually inspected",
    day: "Friday",
    remarks: "3RD OFF",
  ),
  _RecordTemplate(
    category: "Monthly",
    number: 2,
    description: "Pilot ladders (P&S), Storm ladders (Fwd LR, SS LR, PS RB) visually checked & tested.",
    day: "Saturday",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "Monthly",
    number: 3,
    description: "Emergency lighting tested; Fixed fire fighting stop valves checked; Leakage test of C. Holds sprinkler system under pressure provided; Fire pumps including EFP tested; EDG tested; EFP, Fire main with Hydrants tested.",
    day: "Sunday",
    remarks: "CH. OFF. with assist. of El. Eng. and 2nd Eng.",
  ),
  _RecordTemplate(
    category: "Monthly",
    number: 4,
    description: "Gangways P & S monthly inspection provided in acc with S/b C/l 13; All in order.",
    day: "Last Date stated",
    remarks: "CH. OFF. with assist. of Ch. Eng.",
  ),
  _RecordTemplate(
    category: "Quarterly",
    number: 1,
    description: "Int. Shore Connection inspected;",
    day: "Friday",
    remarks: "3RD OFF",
  ),
  _RecordTemplate(
    category: "Quarterly",
    number: 2,
    description: "Fire doors & dampers locally tested",
    day: "Friday",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "Semi-annually",
    number: 1,
    description: "Fire Hoses under Pressure tested",
    day: "Friday",
    remarks: "3RD OFF",
  ),
  _RecordTemplate(
    category: "Annually",
    number: 1,
    description: "Fire Detection system inspected; Flow test of Fire pumps (including EFP) provided. Fire main tested under pressure; Operation test of all Fire Hydrants, Inspection of sprinkler system connection to fire main provided; Blow air test of CO2 piping system done.",
    day: "",
    remarks: "CH. OFF. with assist. of El. Eng. and 2nd Eng.",
  ),
  _RecordTemplate(
    category: "Before Departure",
    number: 1,
    description: "Within 12 h before dep.: The Steering gear was tested ,checked and visually inspected,as per SOLAS Chapter V,Regulation 19-2",
    day: "",
    remarks: "OOW",
  ),
  _RecordTemplate(
    category: "Each Navigation Watch",
    number: 1,
    description: "Auto/ manual steering tested; In order.",
    day: "",
    remarks: "OOW",
  ),
  _RecordTemplate(
    category: "Daily",
    number: 1,
    description: "AM: Visual inspection of C. Hold's Bilges provided; All in order",
    day: "",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "Daily",
    number: 2,
    description: "PM: Visual inspection of C. Holds & C. Hold's Bilges provided; All in order.",
    day: "",
    remarks: "with assist. of Bosun",
  ),
  _RecordTemplate(
    category: "Daily",
    number: 3,
    description: "BNWAS stage 1 alarm tested.",
    day: "",
    remarks: "2ND OFF",
  ),
  _RecordTemplate(
    category: "On Occasion",
    number: 1,
    description: "Maintenance of Falls used in launching of FFLB, RB, LR, etc. (Renewal, greasing, etc.)",
    day: "",
    remarks: "CH. OFF.",
  ),
  _RecordTemplate(
    category: "On Occasion",
    number: 2,
    description: "All Shore services provided in port.",
    day: "",
    remarks: "OOW",
  ),
];

class LogbookRecordsScreen extends StatefulWidget {
  const LogbookRecordsScreen({super.key});
  @override
  State<LogbookRecordsScreen> createState() => _LogbookRecordsScreenState();
}

class _LogbookRecordsScreenState extends State<LogbookRecordsScreen> {
  final _search = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _copy(_RecordTemplate record) async {
    try {
      await Clipboard.setData(ClipboardData(text: record.description));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Record wording copied.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copy failed. Open the record and select the text.'),
      ));
    }
  }

  void _info() {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('About Logbook Records'),
      content: const SingleChildScrollView(child: Text(
        'This section provides sample wording for deck logbook entries '
        'covering routine checks, equipment tests and onboard operations.\n\n'
        'Adapt each entry to the work actually carried out, including the date, '
        'time, results and any relevant observations. Follow your vessel’s '
        'procedures and applicable logbook requirements.',
        style: TextStyle(color: _muted, height: 1.5),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'))],
    ));
  }

  void _details(_RecordTemplate record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${record.category}', style: const TextStyle(
              color: _accent, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            SelectableText(record.description, style: const TextStyle(fontSize: 18, height: 1.6)),
            const SizedBox(height: 20),
            Text('Day / timing: ${record.day.isEmpty ? 'Not specified' : record.day}',
              style: const TextStyle(color: _muted, height: 1.6)),
            const SizedBox(height: 8),
            Text('Responsibility / remarks: ${record.remarks.isEmpty ? 'Not specified' : record.remarks}',
              style: const TextStyle(color: _muted, height: 1.6)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _copy(record),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Record Wording'),
              style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: _navy),
            ),
            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Close')),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final tokens = query.split(RegExp(r'\s+')).where((text) => text.isNotEmpty).toList();
    final visible = _templates.where((record) {
      final text = '${record.description} ${record.day} ${record.remarks} ${record.category}'.toLowerCase();
      return (_category == 'All' || record.category == _category) && tokens.every(text.contains);
    }).toList();
    final categories = ['All', ..._templates.map((record) => record.category).toSet()];
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(title: const Text('Logbook Records'), actions: [
        IconButton(onPressed: _info, tooltip: 'Source information', icon: const Icon(Icons.info_outline)),
      ]),
      body: SafeArea(top: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search description, day or officer',
            prefixIcon: const Icon(Icons.search, color: _accent),
            suffixIcon: _search.text.isEmpty ? null : IconButton(
              onPressed: () => setState(() => _search.clear()),
              tooltip: 'Clear search', icon: const Icon(Icons.close)),
            filled: true, fillColor: _panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DropdownButton<String>(
            value: _category,
            isExpanded: true,
            dropdownColor: _panel,
            items: categories.map((category) => DropdownMenuItem(
              value: category, child: Text(category == 'All' ? 'All Frequencies' : category),
            )).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Align(alignment: Alignment.centerLeft, child: Text(
            '${visible.length} templates',
            style: const TextStyle(color: _muted, fontSize: 12),
          )),
        ),
        Expanded(child: visible.isEmpty
          ? const Center(child: Text('No matching records.', style: TextStyle(color: _muted)))
          : ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final record = visible[index];
                return Card(
                  color: _panel,
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: _outline)),
                  child: InkWell(onTap: () => _details(record), child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${record.category}',
                          style: const TextStyle(color: _accent, fontWeight: FontWeight.w700))),
                        IconButton(onPressed: () => _copy(record),
                          tooltip: 'Copy record wording', icon: const Icon(Icons.copy_outlined, color: _accent)),
                      ]),
                      const SizedBox(height: 8),
                      Text(record.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                      const SizedBox(height: 16),
                      if (record.day.isNotEmpty)
                        Text('Day / timing: ${record.day}', style: const TextStyle(color: _muted, height: 1.5)),
                      if (record.remarks.isNotEmpty)
                        Text('Responsibility / remarks: ${record.remarks}',
                          style: const TextStyle(color: _muted, height: 1.5)),
                    ]),
                  )),
                );
              },
            )),
      ])),
    );
  }
}
