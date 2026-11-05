import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:flutter_test/flutter_test.dart';
import '../lib/safety_depth_model.dart';
import '../lib/safety_depth_report.dart';

SafetyDepthResult example({String cat = 'D',bool tables = false}) => SafetyDepthResult.calculate(
  VesselSafetySettings(name: 'Судно Test',lengthBP: 198.8,breadth: 30.1,
    cbMethod: tables ? tableCbMethod : calculateCbMethod),
  SafetyDepthInput(foreDraft: 9.41,aftDraft: 9.71,displacementMT: 35496,waterDensity: 1.025,
    chartedDepth: 8.8,speedThroughWater: 6,heelDegrees: -2,densityCorrection: 0.1,catzoc: cat,manualDepthAllowance: 3,depthAllowanceBasis: 'Port assessment',tableCb: tables ? 0.7 : null),
  calculatedUTC: DateTime.utc(2026,11,2,12));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Excel includes formulas, numeric snapshot, vessel and D/U warning', () {
    final r = example();
    final book = ex.Excel.decodeBytes(buildSafetyDepthExcel(r));
    expect(book.tables.keys,['Safety Depth']);
    final sheet = book['Safety Depth'];
    ex.CellValue? value(String cell) => sheet.cell(ex.CellIndex.indexByString(cell)).value;
    expect((value('B2') as ex.TextCellValue).value.toString(),'Судно Test');
    expect((value('B29') as ex.FormulaCellValue).formula,contains('B17/B18'));
    expect((value('B35') as ex.FormulaCellValue).formula,'SUM(B27,B30:B34)');
    expect((value('B36') as ex.FormulaCellValue).formula,'ROUNDUP(B35,2)');
    expect((value('E36') as ex.DoubleCellValue).value,r.displayedDepth);
    expect((value('A6') as ex.TextCellValue).value.toString(),contains('manual depth allowance'));
    expect(value('B44'), anyOf(ex.IntCellValue(3), ex.DoubleCellValue(3)));
    expect((value('B34') as ex.FormulaCellValue).formula,contains('NA()'));
    expect((value('B38') as ex.FormulaCellValue).formula,contains('manual allowance required'));
  });
  test('Excel table mode contains selected Cb as a number', () {
    final book = ex.Excel.decodeBytes(buildSafetyDepthExcel(example(tables: true)));
    final value = book['Safety Depth'].cell(ex.CellIndex.indexByString('B24')).value as ex.DoubleCellValue;
    expect(value.value,0.7);
  });
  test('PDF generation supports a Cyrillic vessel name and D/U report', () async {
    final bytes = await buildSafetyDepthPdf(example());
    expect(ascii.decode(bytes.take(5).toList()),'%PDF-');
    expect(bytes.length,greaterThan(5000));
  });
}
