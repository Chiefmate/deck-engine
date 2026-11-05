import 'dart:typed_data';
import 'package:excel/excel.dart' as ex;
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'safety_depth_model.dart';
import 'safety_report_font.dart';

const _methodNote = 'Squat = Cb * STW^2 / 50. Heel correction = 0.008 * breadth * ABS(heel degrees). '
  'These empirical relations and the simple mean fore/aft draught are approximations; '
  'check their applicability to the vessel and operating conditions. '
  'CATZOC vertical accuracy is a 95% measure, not a guaranteed seabed limit. '
  'Density correction is additional and must not duplicate a change already included in the draughts. '
  'Chart allowance is evaluated at the entered charted depth. No tidal credit, passage-safety assessment '
  'or automatic ECDIS contour selection is included.';

List<List<String>> _inputRows(SafetyDepthResult r) => [
  ['Vessel Name',r.vessel.name],['Calculated UTC',r.calculatedUTC.toIso8601String()],
  ['Model Version',safetyDepthModelVersion],['LBP (m)',r.vessel.lengthBP.toString()],
  ['Breadth (m)',r.vessel.breadth.toString()],['Cb Method',r.vessel.methodLabel],
  ['Fore Draft (m)',r.input.foreDraft.toString()],['Aft Draft (m)',r.input.aftDraft.toString()],
  ['Displacement (t)',r.input.displacementMT.toString()],['Water Density (t/m3)',r.input.waterDensity.toString()],
  ['Min Depth from Chart (m)',r.input.chartedDepth.toString()],
  ['Vessel Speed - STW (kts)',r.input.speedThroughWater.toString()],
  ['Heel Angle (degrees)',r.input.heelDegrees.toString()],
  ['Density Correction (m)',r.input.densityCorrection.toString()],['CATZOC',r.input.catzoc],
  if (r.usesManualDepthAllowance) ...[
    ['Manual Depth Allowance (m)',r.chartAllowance.toString()],
    ['Allowance Basis',r.input.depthAllowanceBasis ?? ''],
  ],
  if (r.vessel.cbMethod == tableCbMethod) ['Cb from Vessel Tables',r.input.tableCb.toString()],
];

Future<Uint8List> buildSafetyDepthPdf(SafetyDepthResult r) async {
  final font = pw.Font.ttf(ByteData.sublistView(safetyReportFontBytes()));
  final doc = pw.Document(title: 'Safety Depth - ${r.vessel.name}',author: 'Vessel Assistant');
  final navy = PdfColor.fromHex('#112437'), teal = PdfColor.fromHex('#147D75');
  pw.Widget section(String title) => pw.Padding(padding: const pw.EdgeInsets.only(top: 16,bottom: 8),
    child: pw.Text(title,style: pw.TextStyle(fontSize: 13,fontWeight: pw.FontWeight.bold,color: navy)));
  doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4,margin: const pw.EdgeInsets.all(34),
    theme: pw.ThemeData.withFont(base: font,bold: font),
    header: (_) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10),child: pw.Text(
      'VESSEL ASSISTANT / DECK / NAVIGATION',style: pw.TextStyle(fontSize: 8,color: teal))),
    footer: (context) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,children: [
      pw.Text('Calculated UTC: ${r.calculatedUTC.toIso8601String()}',style: const pw.TextStyle(fontSize: 7)),
      pw.Text('${context.pageNumber} / ${context.pagesCount}',style: const pw.TextStyle(fontSize: 7)),
    ]),build: (_) => [
      pw.Text('SAFETY DEPTH',style: pw.TextStyle(fontSize: 24,color: navy)),
      pw.SizedBox(height: 6),
      pw.Text('${r.displayedDepth.toStringAsFixed(2)} m',style: pw.TextStyle(fontSize: 30,color: teal)),
      pw.Text('Rounded upward to 0.01 m. Unrounded sum: ${r.total} m.',style: const pw.TextStyle(fontSize: 9)),
      if (r.warning != null) pw.Container(margin: const pw.EdgeInsets.only(top: 12),padding: const pw.EdgeInsets.all(10),
        color: PdfColor.fromHex('#FFF0CD'),child: pw.Text(r.warning!,style: const pw.TextStyle(fontSize: 10))),
      section('Vessel Particulars and Current Inputs'),
      pw.TableHelper.fromTextArray(data: _inputRows(r),headers: ['Input','Value'],
        cellStyle: const pw.TextStyle(fontSize: 9),headerStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E4F2F0')),
        cellPadding: const pw.EdgeInsets.all(5),columnWidths: {0: const pw.FlexColumnWidth(1.1),1: const pw.FlexColumnWidth(1.5)}),
      section('Calculation Details'),
      pw.TableHelper.fromTextArray(headers: ['Item','Result','Formula with Entered Values'],
        data: r.calculationLines.map((l) => [l.label,
          '${l.value.toStringAsFixed(l.unit == '-' ? 8 : 6)} ${l.unit == '-' ? '' : l.unit}',l.formula]).toList(),
        cellStyle: const pw.TextStyle(fontSize: 8),headerStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.all(5),headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E4F2F0')),
        columnWidths: {0: const pw.FlexColumnWidth(1.3),1: const pw.FlexColumnWidth(1),2: const pw.FlexColumnWidth(2.4)}),
      section('Formula and Assumptions'),
      pw.Text('Safety Depth = Max Draft + 10% of Max Draft + Squat + Heel Correction + Density Correction + ENC ZOC Correction.',
        style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 6),pw.Text(_methodNote,style: const pw.TextStyle(fontSize: 8)),
      pw.SizedBox(height: 6),pw.Text('Cb: displaced volume / (LBP * breadth * mean draught). '
        'ENC ZOC: A1 = 0.5 + 0.01d; A2/B = 1 + 0.02d; C = 2 + 0.05d; D/U require a justified manual allowance; no C substitution. '
        'd is charted depth in metres.',style: const pw.TextStyle(fontSize: 8)),
    ]));
  return doc.save();
}

Uint8List buildSafetyDepthExcel(SafetyDepthResult r) {
  final book = ex.Excel.createExcel();
  final sheet = book['Safety Depth'];
  book.setDefaultSheet('Safety Depth');
  if (book.tables.containsKey('Sheet1')) book.delete('Sheet1');
  ex.Data cell(String a) => sheet.cell(ex.CellIndex.indexByString(a));
  void text(String a,String v) { cell(a).value = ex.TextCellValue(v); }
  void num(String a,double v) { cell(a).value = ex.DoubleCellValue(v); }
  void formula(String a,String v) { cell(a).value = ex.FormulaCellValue(v); }
  void merged(String from,String to,String value) {
    sheet.merge(ex.CellIndex.indexByString(from),ex.CellIndex.indexByString(to)); text(from,value);
  }
  final dark = ex.ExcelColor.fromHexString('FF112437'), pale = ex.ExcelColor.fromHexString('FFE4F2F0');
  for (var c=0;c<5;c++) { sheet.setColumnWidth(c,[34.0,27.0,12.0,84.0,24.0][c]); }
  merged('A1','E1','SAFETY DEPTH - FULL CALCULATION');
  text('A2','Vessel Name'); text('B2',r.vessel.name);
  text('A3','Calculated UTC'); text('B3',r.calculatedUTC.toIso8601String());
  text('A4','Model Version'); text('B4',safetyDepthModelVersion);
  text('A5','Safety Depth (m)'); formula('B5','B36'); text('C5','m'); num('E5',r.displayedDepth);
  merged('A6','E6',r.warning ?? 'CATZOC ${r.input.catzoc}. Values in column E are the exported application results. Column B contains the editable calculation.');
  sheet.setRowHeight(5,64);
  for (final row in [9,14,26]) {
    merged('A$row','E$row',row == 9 ? 'VESSEL PARTICULARS' : row == 14 ? 'CURRENT INPUTS' : 'CALCULATION');
  }
  text('A10','LBP'); num('B10',r.vessel.lengthBP); text('C10','m');
  text('A11','Breadth'); num('B11',r.vessel.breadth); text('C11','m');
  text('A12','Cb Method'); text('B12',r.vessel.methodLabel);
  final inputs = <List<Object>>[
    [15,'Fore Draft',r.input.foreDraft,'m'],[16,'Aft Draft',r.input.aftDraft,'m'],
    [17,'Displacement',r.input.displacementMT,'t'],[18,'Water Density',r.input.waterDensity,'t/m3'],
    [19,'Min Depth from Chart',r.input.chartedDepth,'m'],[20,'Vessel Speed - STW',r.input.speedThroughWater,'kts'],
    [21,'Heel Angle',r.input.heelDegrees,'degrees'],[22,'Density Correction',r.input.densityCorrection,'m'],
  ];
  for (final i in inputs) {
    final row = i[0] as int; text('A$row',i[1] as String); num('B$row',i[2] as double); text('C$row',i[3] as String);
  }
  text('A23','CATZOC'); text('B23',r.input.catzoc);
  text('A24','Cb from Vessel Tables');
  if (r.input.tableCb != null) { num('B24',r.input.tableCb!); } else { text('B24','Not used'); }
  text('A44','Manual D/U Depth Allowance (m)');
  if (r.usesManualDepthAllowance) num('B44',r.chartAllowance);
  text('A45','Allowance Basis'); text('B45',r.input.depthAllowanceBasis ?? '');
  final formulas = <String>[
    'MAX(B15,B16)','(B15+B16)/2','IF(B12="Calculate Cb",(B17/B18)/(B10*B11*B28),B24)',
    'B27*0.1','B29*B20^2/50','0.008*B11*ABS(B21)','B22',
    'IF(B23="A1",0.5+0.01*B19,IF(OR(B23="A2",B23="B"),1+0.02*B19,IF(B23="C",2+0.05*B19,IF(AND(OR(B23="D",B23="U"),ISNUMBER(B44),B44>=0,B45<>""),B44,NA()))))',
    'SUM(B27,B30:B34)','ROUNDUP(B35,2)',
  ];
  text('D25','Formula / explanation'); text('E25','App Result (snapshot)');
  for (var i=0;i<r.calculationLines.length;i++) {
    final row = 27+i, line = r.calculationLines[i];
    text('A$row',line.label); formula('B$row',formulas[i]); text('C$row',line.unit);
    text('D$row','=${formulas[i]}'); num('E$row',line.value);
    sheet.setRowHeight(row-1,row == 29 || row == 34 ? 48 : 30);
  }
  text('A38','CATZOC warning');
  merged('B38','E38','');
  formula('B38','IF(OR(B23="D",B23="U"),"D/U: manual allowance required in B44 with basis in B45. Reliability not established.","No D/U substitution")');
  sheet.setRowHeight(37,60);
  merged('A40','E40','METHOD AND ASSUMPTIONS');
  merged('A41','E41',_methodNote); sheet.setRowHeight(40,110);
  merged('A43','E43','Column E is a fixed snapshot at export. Column B formulas recalculate in Excel/LibreOffice. After editing inputs, recheck Cb, units and method applicability.');
  sheet.setRowHeight(42,45);
  for (var row=0;row<45;row++) {
    for (var col=0;col<5;col++) {
      final c = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col,rowIndex: row));
      c.cellStyle = ex.CellStyle(fontFamily: 'Calibri',fontSize: 11,
        textWrapping: ex.TextWrapping.WrapText,verticalAlign: ex.VerticalAlign.Center,
        numberFormat: ex.NumFormat.custom(formatCode: '0.000000'));
    }
  }
  for (final row in [1,9,14,26,40]) {
    for (var col=0;col<5;col++) { sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col,rowIndex: row-1)).cellStyle =
      ex.CellStyle(bold: true,fontColorHex: ex.ExcelColor.white,backgroundColorHex: dark,fontSize: 12); }
    sheet.setRowHeight(row-1,25);
  }
  for (final a in ['A5','B5','C5','E5','A36','B36','C36','D36','E36']) {
    cell(a).cellStyle = ex.CellStyle(bold: true,backgroundColorHex: pale,fontSize: 14,
      numberFormat: ex.NumFormat.custom(formatCode: '0.00'));
  }
  if (r.warning != null) cell('A6').cellStyle = ex.CellStyle(
    fontColorHex: ex.ExcelColor.fromHexString('FF7A4000'),backgroundColorHex: ex.ExcelColor.fromHexString('FFFFF0CD'),
    textWrapping: ex.TextWrapping.WrapText,verticalAlign: ex.VerticalAlign.Center);
  final bytes = book.encode();
  if (bytes == null) throw StateError('Excel report could not be encoded.');
  return Uint8List.fromList(bytes);
}

Future<void> exportSafetyDepthReport(SafetyDepthResult r,String type) async {
  if (!['pdf','xlsx'].contains(type)) throw ArgumentError.value(type,'type');
  final bytes = type == 'pdf' ? await buildSafetyDepthPdf(r) : buildSafetyDepthExcel(r);
  final stamp = r.calculatedUTC.toIso8601String().replaceAll(RegExp(r'[^0-9TZ]'),'');
  final vessel = r.vessel.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'),'_');
  await FileSaver.instance.saveFile(name: 'Safety_Depth_${vessel}_$stamp',bytes: bytes,
    fileExtension: type,mimeType: MimeType.custom,
    customMimeType: type == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}
