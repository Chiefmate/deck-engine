import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ukc_model.dart';

const _navy=Color(0xFF081522), _panel=Color(0xFF112437), _accent=Color(0xFF4DDAC6), _muted=Color(0xFF9BB0C3);
class UkcCalculatorScreen extends StatefulWidget {
  const UkcCalculatorScreen({super.key});
  @override
  State<UkcCalculatorScreen> createState()=>_UkcCalculatorScreenState();
}
class _UkcCalculatorScreenState extends State<UkcCalculatorScreen> {
  static const _key='deck_ukc_profile_v1';
  final _profileForm=GlobalKey<FormState>(),_form=GlobalKey<FormState>();
  final Map<String,TextEditingController> _f={
    for(final k in ['name','length','breadth','location','fore','aft','max','disp','rho','cb','heel','density','speed','depth','tide','swell','squat','manualDepth','basis'])
      k:TextEditingController(text:k=='rho'?'1.025':['heel','density','tide','swell'].contains(k)?'0.00':''),
  };
  bool _manualCb=false,_manualSquat=false,_confined=true,_loading=true,_saving=false;
  String? _catzoc,_error,_loadError;
  UkcResult? _r;
  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){for(final c in _f.values){c.dispose();}super.dispose();}
  double? num(String k){final v=double.tryParse(_f[k]!.text.trim().replaceAll(',','.'));return v!=null&&v.isFinite?v:null;}
  void invalidate()=>setState((){_r=null;_error=null;});
  Future<void> _load() async {
    try {
      final raw=await SharedPreferencesAsync().getString(_key);
      if(!mounted)return;
      if(raw!=null){final j=jsonDecode(raw) as Map<String,dynamic>;
        for(final k in ['name','length','breadth']){if(j[k] is String)_f[k]!.text=j[k] as String;}
        _manualCb=j['manualCb']==true;
      }
    }catch(_){if(mounted)_loadError='Saved vessel settings could not be loaded. Enter and save them again.';}
    if(mounted)setState(()=>_loading=false);
  }
  Future<void> _save() async {
    if(!_profileForm.currentState!.validate())return;
    setState(()=>_saving=true);
    try{await SharedPreferencesAsync().setString(_key,jsonEncode({
      for(final k in ['name','length','breadth'])k:_f[k]!.text.trim(),'manualCb':_manualCb}));
      if(mounted){setState(()=>_loadError=null);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vessel settings saved on this device.')));}
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not save vessel settings.')));}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  Widget field(String k,String label,{bool text=false,bool optional=false,bool signed=false,bool zero=false,String? help})=>Padding(
    padding:const EdgeInsets.only(bottom:16),child:TextFormField(controller:_f[k],enabled:!_saving,
      decoration:InputDecoration(labelText:label,helperText:help,helperMaxLines:4,errorMaxLines:3,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
      keyboardType:text?TextInputType.text:TextInputType.numberWithOptions(decimal:true,signed:signed),
      onChanged:(_)=>invalidate(),validator:(s){
        if((s??'').trim().isEmpty)return optional?null:'Enter a value.';
        if(text)return null;
        final v=num(k);if(v==null)return 'Enter a finite number.';
        if(k=='heel')return v.abs()>=90?'Heel must be between -90 and 90 degrees.':null;
        if(!signed && (zero?v<0:v<=0))return zero?'Enter 0 or a positive value.':'Enter a positive value.';
        if(k=='cb'&&v>1)return 'Cb must not exceed 1.';
        return null;
      }));
  Widget card(List<Widget> children)=>Padding(padding:const EdgeInsets.only(bottom:20),child:Container(
    width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children)));
  Widget title(String s)=>Padding(padding:const EdgeInsets.only(bottom:18),child:Text(s,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)));
  Widget value(String label,double? v,{int digits=2,String unit='m'})=>Padding(padding:const EdgeInsets.only(bottom:14),child:Text('$label: ${v==null?'—':v.toStringAsFixed(digits)} $unit',style:const TextStyle(color:_accent)));
  void calculate(){
    final a=_profileForm.currentState!.validate(),b=_form.currentState!.validate();
    if(!a||!b){invalidate();return;}
    try {
      double v(String k)=>num(k)!;
      final result=UkcResult.calculate(UkcInput(length:v('length'),breadth:v('breadth'),fore:v('fore'),aft:v('aft'),
        maxDraft:num('max'),displacement:_manualCb?null:v('disp'),manualCb:_manualCb?v('cb'):null,
        waterDensity:v('rho'),depth:v('depth'),tide:v('tide'),speed:v('speed'),heel:v('heel'),
        densityCorrection:v('density'),swell:v('swell'),catzoc:_catzoc!,confined:_confined,
        manualSquat:_manualSquat?v('squat'):null,manualDepth:['D','U'].contains(_catzoc)?num('manualDepth'):null,
        depthBasis:_f['basis']!.text.trim()));
      setState((){_r=result;_error=null;});
    } on FormatException catch(e){setState((){_r=null;_error=e.message;});}
  }
  Future<void> copy(UkcResult r) async {
    try{await Clipboard.setData(ClipboardData(text:[
      'UKC CALCULATION', 'Vessel: ${_f['name']!.text}', 'Location: ${_f['location']!.text}',
      'Calculated UTC: ${r.calculatedUtc.toIso8601String()}', 'Water type: ${_confined?'Confined':'Open'}',
      'STW: ${ukcDisplay(r.input.speed)} kn', 'Swell allowance: ${ukcDisplay(r.input.swell)} m',
      'Displayed values rounded to 2 decimals; calculations use full precision.',
      ...r.details,
      if(!r.complete)'Assessment incomplete',
      if(r.usesManualDepth)'D is worse than C; U is unassessed. A manual allowance does not establish seabed reliability.',
      'Approximate selected methods; this calculation is not a passage-safety approval.',
    ].join('\n')));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Calculation copied.')));}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not copy calculation.')));}
  }
  Widget result(UkcResult r)=>card([
    title('Calculated UKC'),
    Text(r.complete?'${r.calculatedUkc!.toStringAsFixed(2)} m':'Assessment incomplete',style:const TextStyle(color:_accent,fontSize:34,fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    if(!r.complete)const Text('CATZOC D/U requires a justified manual depth allowance and its basis. Final UKC is unavailable.',style:TextStyle(color:Colors.amber)),
    value('Static UKC',r.staticUkc),
    if(r.usesManualDepth)const Padding(padding:EdgeInsets.only(top:12),child:Text('D is worse than C; U is unassessed. Manual input does not establish seabed reliability.',style:TextStyle(color:Colors.amber))),
    const SizedBox(height:12),const Text('Displayed values are rounded to 2 decimals. Calculations use full precision; rounded formula terms may not reproduce the exact result.',style:TextStyle(color:_muted)),
    ExpansionTile(title:const Text('Calculation Details'),tilePadding:EdgeInsets.zero,children:[
      for(final line in r.details)Padding(padding:const EdgeInsets.only(bottom:12),child:Align(alignment:Alignment.centerLeft,child:SelectableText(line))),
    ]),
    if(r.complete && r.input.manualSquat==null)ExpansionTile(title:const Text('UKC by Speed'),tilePadding:EdgeInsets.zero,children:[
      const Text('Same inputs and automatic squat method; only STW changes. These speeds are comparisons, not recommendations.',style:TextStyle(color:_muted)),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('STW (kn)')),DataColumn(label:Text('UKC (m)'))],rows:[
        for(final speed in (<double>{0,math.max(0.0,r.input.speed-2),r.input.speed,r.input.speed+2,r.input.speed+4,r.input.speed+6}.toList()..sort()))
          DataRow(cells:[DataCell(Text(speed.toStringAsFixed(2))),DataCell(Text(r.atSpeed(speed).toStringAsFixed(2)))]),
      ])),
    ]),
    if(r.input.manualSquat!=null)const Text('Speed comparison unavailable with manually entered squat.',style:TextStyle(color:_muted)),
    OutlinedButton.icon(onPressed:()=>copy(r),icon:const Icon(Icons.copy_outlined),label:const Text('Copy Calculation')),
  ]);
  @override
  Widget build(BuildContext context){
    final fore=num('fore'),aft=num('aft');
    final mean=fore!=null&&aft!=null&&fore>0&&aft>0?fore/2+aft/2:null;
    final maximum=mean==null?null:math.max(math.max(fore!,aft!),num('max')??0.0);
    double? cb=_manualCb?num('cb'):null;
    if(!_manualCb && mean!=null && ['disp','rho','length','breadth'].every((k)=>num(k)!=null&&num(k)!>0)){
      final candidate=num('disp')!/(num('rho')!*num('length')!*num('breadth')!*mean);
      if(candidate.isFinite&&candidate>0&&candidate<=1)cb=candidate;
    }
    return Scaffold(backgroundColor:_navy,appBar:AppBar(title:const Text('UKC Calculator')),
      body:_loading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Padding(padding:EdgeInsets.only(bottom:20),child:Text('Estimate under-keel clearance for the entered vessel and passage conditions.')),
        if(_loadError!=null)Text(_loadError!,style:const TextStyle(color:Colors.amber)),
        Form(key:_profileForm,child:card([
          title('Vessel Particulars'),field('name','Vessel Name',text:true),field('length','LBP (m)'),field('breadth','Breadth (m)'),
          DropdownButtonFormField<bool>(value:_manualCb,decoration:const InputDecoration(labelText:'Cb Method'),items:const [DropdownMenuItem(value:false,child:Text('Calculate Cb')),DropdownMenuItem(value:true,child:Text('Enter Cb Manually'))],onChanged:_saving?null:(v){setState((){_manualCb=v!;_r=null;_error=null;});}),
          OutlinedButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving...':'Save Vessel Settings')),
        ])),
        Form(key:_form,child:Column(children:[
          card([title('Current Condition'),field('fore','Fore Draft (m)'),field('aft','Aft Draft (m)'),
            field('max','Additional Max Draft (m)',optional:true,help:'Optional: enter a known deeper static draft. The greatest entered draft is used.'),
            value('Mean Draft — automatic',mean),value('Maximum Draft — automatic',maximum),
            if(!_manualCb)field('disp','Displacement (t)'),field('rho','Water Density (t/m³)'),
            if(_manualCb)field('cb','Cb — Manual'),value('Cb used',cb,digits:6,unit:''),
            field('heel','Heel Angle (°)',signed:true),
            field('density','Density Correction (m)',zero:true,help:'Leave 0 if the entered drafts already reflect the current water density.'),
          ]),
          card([title('Passage Conditions'),field('location','Port / Location',text:true,optional:true),
            DropdownButtonFormField<bool>(value:_confined,decoration:const InputDecoration(labelText:'Water Type'),items:const [DropdownMenuItem(value:true,child:Text('Confined Water')),DropdownMenuItem(value:false,child:Text('Open Water'))],onChanged:(v){setState((){_confined=v!;_r=null;_error=null;});}),
            const SizedBox(height:18),field('speed','Speed Through Water (kn)',zero:true),
            SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Manual Squat'),value:_manualSquat,onChanged:(v){setState((){_manualSquat=v;_r=null;_error=null;});}),
            if(_manualSquat)field('squat','Squat at Entered STW (m)',zero:true),
            field('depth','Minimum Charted Depth (m)'),field('tide','Tide / Water Level (m)',signed:true,help:'Use the same vertical datum as the charted depth; negative values are allowed.'),
            field('swell','Swell Correction (m)',zero:true,help:'Allowance for wave-induced vertical motion, not simply wave height. Zero means no allowance included; review for the passage.'),
            DropdownButtonFormField<String>(value:_catzoc,decoration:const InputDecoration(labelText:'CATZOC'),items:['A1','A2','B','C','D','U'].map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){setState((){_catzoc=v;_r=null;_error=null;});},validator:(v)=>v==null?'Select CATZOC.':null),
            if(['D','U'].contains(_catzoc))...[
              const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('D/U: no automatic numerical allowance. Without both a manual allowance and its basis, the assessment remains incomplete.',style:TextStyle(color:Colors.amber))),
              field('manualDepth','Manual Depth Allowance (m)',zero:true,optional:true),field('basis','Basis for Manual Allowance',text:true,optional:true),
            ],
          ]),
        ])),
        FilledButton.icon(onPressed:_saving?null:calculate,icon:const Icon(Icons.calculate_outlined),label:const Padding(padding:EdgeInsets.all(16),child:Text('Calculate UKC'))),
        if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(_error!,style:const TextStyle(color:Colors.amber))),
        const SizedBox(height:20),if(_r!=null)result(_r!),
        const ExpansionTile(title:Text('About This Calculation'),children:[Padding(padding:EdgeInsets.all(12),child:Text(
          'Cb = displacement / (density × LBP × breadth × mean draft), or manual.\n'
          'Squat = Cb × STW² / 50 (confined) or / 100 (open), unless manual.\n'
          'Heel allowance = breadth / 2 × tan(abs(heel in degrees) × pi / 180).\n'
          'CATZOC allowance: A1 = 0.5 + 0.01d; A2/B = 1 + 0.02d; C = 2 + 0.05d. D/U require justified manual input.\n'
          'Calculated UKC = charted depth + level - maximum draft - density correction - depth allowance - squat - heel allowance - swell allowance.\n\n'
          'These are approximate selected methods, not a universal IMO formula. Use vessel and port procedures and account for additional uncertainties within the relevant allowances. Avoid counting a correction twice. CATZOC does not guarantee detection of every obstruction. A manual D/U allowance does not establish seabed reliability. This calculation is not a passage-safety approval.',style:TextStyle(color:_muted,height:1.5)))]),
      ])))));
  }
}
