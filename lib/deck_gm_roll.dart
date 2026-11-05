import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gm_roll_model.dart';

const _navy=Color(0xFF081522), _panel=Color(0xFF112437), _accent=Color(0xFF4DDAC6), _muted=Color(0xFF9BB0C3);
class GmRollScreen extends StatefulWidget {
  const GmRollScreen({super.key});
  @override
  State<GmRollScreen> createState()=>_GmRollScreenState();
}
class _GmRollScreenState extends State<GmRollScreen> with WidgetsBindingObserver {
  final _form=GlobalKey<FormState>();
  final _breadth=TextEditingController(),_coefficient=TextEditingController(text:'0.80');
  final _seconds=TextEditingController();
  final _watch=Stopwatch();
  Timer? _ticker;
  bool _interrupted=false;
  GmRollEstimate? _result;
  String? _error;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);_ticker?.cancel();_watch.stop();for(final c in [_breadth,_coefficient,_seconds]){c.dispose();}super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed && _watch.isRunning){
      _watch.stop();_ticker?.cancel();
      if(mounted)setState(()=>_interrupted=true);
    }
  }
  double? number(String s){final v=double.tryParse(s.trim().replaceAll(',','.'));return v!=null&&v.isFinite?v:null;}
  void invalidate(){_result=null;_error=null;}
  Widget card(Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20)),child:child);
  Widget field(TextEditingController c,String label,{bool integer=false})=>Padding(padding:const EdgeInsets.only(bottom:18),child:TextFormField(controller:c,decoration:InputDecoration(labelText:label,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),keyboardType:TextInputType.numberWithOptions(decimal:!integer),onChanged:(_)=>setState(invalidate),validator:(s){if(integer){final n=int.tryParse((s??'').trim());return n==null||n<=0?'Enter a positive whole number.':null;}final n=number(s??'');return n==null||n<=0?'Enter a positive finite number.':null;}));
  void start(){
    _ticker?.cancel();_watch..reset()..start();
    setState((){_interrupted=false;invalidate();});
    _ticker=Timer.periodic(const Duration(milliseconds:100),(_){if(mounted)setState((){});});
  }
  void finish(){
    if(!_watch.isRunning||_interrupted)return;
    _watch.stop();_ticker?.cancel();
    setState((){_seconds.text=(_watch.elapsedMicroseconds/1000000).toStringAsFixed(2);invalidate();});
  }
  void reset(){_ticker?.cancel();_watch..stop()..reset();setState((){_interrupted=false;});}
  void calculate(){
    final enteredTime=number(_seconds.text);
    if(enteredTime!=null && enteredTime>0){_seconds.text=enteredTime.toStringAsFixed(2);}
    if(!_form.currentState!.validate())return;
    try{final r=GmRollEstimate.calculate(breadth:number(_breadth.text)!,coefficient:number(_coefficient.text)!,elapsedSeconds:number(_seconds.text)!,cycles:1);setState((){_result=r;_error=null;});}
    on FormatException catch(e){setState((){_result=null;_error=e.message;});}
  }
  Future<void> copy(GmRollEstimate r) async {
    try{await Clipboard.setData(ClipboardData(text:'GM ESTIMATE - ROLL PERIOD\nBreadth: ${r.breadth} m\nCoefficient k: ${r.coefficient}\nMeasurement: one complete roll\nRoll period T: ${r.periodSeconds.toStringAsFixed(2)} s\nGM = (${r.coefficient} * ${r.breadth} / ${r.periodSeconds})^2 = ${r.gm} m\nApproximate estimate; observed wave-forced rolling may not represent the natural roll period. Not a stability compliance assessment.'));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Calculation copied.')));}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not copy calculation.')));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:_navy,appBar:AppBar(title:const Text('GM Estimate — Roll Period')),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('Estimate initial transverse GM from the measured roll period and vessel breadth.',style:TextStyle(fontSize:18,height:1.5)),
    const SizedBox(height:10),const Text('Approximate estimate. Wave-forced rolling at sea may not reflect the natural roll period.',style:TextStyle(color:Colors.amber,height:1.5)),const SizedBox(height:20),
    card(const ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('How to Measure'),children:[Padding(padding:EdgeInsets.only(bottom:16),child:Text(
      '1. Prefer calm conditions with small, regular rolls. Waves, manoeuvring and active stabilisation can distort the measured period. Use the vessel-specific method where available.\n\n'
      '2. Tap Start at a clearly identified maximum heel on one side.\n\n'
      '3. One full cycle: from that side, through the opposite side, back to the same maximum heel. Side-to-opposite-side is only half a cycle.\n\n'
      '4. Tap Stop & Use immediately on the first return to maximum heel on the starting side, after passing through the opposite side. Measure exactly ONE complete cycle.\n\n'
      '5. The measured time is your roll period T. You can also enter one complete roll period manually. Do not enter the total time for several cycles.\n\n'
      '6. If checking again, measure a new single cycle. Irregular rolling and button timing errors make this approximate estimate less reliable.\n\n'
      'If the app loses focus or the phone locks during timing, start a new measurement.',style:TextStyle(color:_muted,height:1.5)))])),
    const SizedBox(height:20),
    card(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Stopwatch',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:8),
      Text('${(_watch.elapsedMicroseconds/1000000).toStringAsFixed(2)} s',style:const TextStyle(fontSize:36,color:_accent,fontFamily:'monospace')),
      if(_interrupted)const Padding(padding:EdgeInsets.only(top:8),child:Text('Measurement interrupted. Start a new measurement.',style:TextStyle(color:Colors.amber))),
      const SizedBox(height:16),Wrap(spacing:10,runSpacing:10,children:[
        FilledButton(onPressed:_watch.isRunning?null:start,child:const Text('Start')),
        OutlinedButton(onPressed:_watch.isRunning&&!_interrupted?finish:null,child:const Text('Stop & Use')),
        TextButton(onPressed:reset,child:const Text('Reset Stopwatch')),
      ]),const SizedBox(height:8),const Text('Measure ONE full cycle: Start at maximum heel on one side. Stop on the first return to maximum heel on that same side after rolling to the opposite side.',style:TextStyle(color:_muted,height:1.4)),
    ])),const SizedBox(height:24),
    Form(key:_form,child:Column(children:[field(_breadth,'Breadth B (m)'),field(_coefficient,'Roll Coefficient k'),field(_seconds,'Roll Period (seconds)')])),
    FilledButton.icon(onPressed:_watch.isRunning?null:calculate,icon:const Icon(Icons.calculate_outlined),label:const Padding(padding:EdgeInsets.all(16),child:Text('Calculate GM Estimate'))),
    if(_error!=null)Padding(padding:const EdgeInsets.only(top:16),child:Text(_error!,style:const TextStyle(color:Colors.amber))),
    if(_result!=null)...[const SizedBox(height:20),card(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('ESTIMATED GM',style:TextStyle(color:_muted,letterSpacing:1.5)),Text('${_result!.gm.toStringAsFixed(2)} m',style:const TextStyle(fontSize:36,color:_accent,fontWeight:FontWeight.bold)),
      Text('Roll period: ${_result!.periodSeconds.toStringAsFixed(2)} s'),const SizedBox(height:12),
      Text('T = ${_result!.periodSeconds.toStringAsFixed(2)} s\nGM ≈ (k × B / T)²',style:const TextStyle(color:_muted,height:1.5)),
      const SizedBox(height:14),OutlinedButton.icon(onPressed:()=>copy(_result!),icon:const Icon(Icons.copy_outlined),label:const Text('Copy Calculation')),
    ]))],const SizedBox(height:22),
    const Text('Why is k initially 0.80?',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:8),
    const Text('ClassNK guidance presents the approximate relation T ≈ 0.8 × B / √GM (B in metres, T in seconds). '
      'The coefficient depends on vessel characteristics and mass distribution. 0.80 is an initial approximation, not a universal calibrated value. '
      'Replace it with the applicable coefficient from your vessel documentation. This estimate does not replace the approved stability calculation.',style:TextStyle(color:_muted,height:1.5)),
  ])))));
}
