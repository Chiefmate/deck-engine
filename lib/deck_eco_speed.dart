import 'package:flutter/material.dart';
import 'eta_model.dart';
import 'eco_speed_model.dart';

class EcoSpeedScreen extends StatefulWidget {
  const EcoSpeedScreen({super.key});
  @override
  State<EcoSpeedScreen> createState()=>_EcoSpeedScreenState();
}
class _EcoSpeedScreenState extends State<EcoSpeedScreen> {
  final _form=GlobalKey<FormState>();
  final _distance=TextEditingController(),_eco=TextEditingController(),_full=TextEditingController();
  late DateTime _departure,_arrival;
  EcoSpeedPlan? _result;
  String? _error;
  @override
  void initState(){super.initState();final n=DateTime.now().toUtc();_departure=DateTime.utc(n.year,n.month,n.day,n.hour,n.minute);_arrival=_departure.add(const Duration(days:1));}
  @override
  void dispose(){_distance.dispose();_eco.dispose();_full.dispose();super.dispose();}
  double? number(String s){final n=double.tryParse(s.trim().replaceAll(',','.'));return n!=null&&n.isFinite?n:null;}
  void invalidate(){_result=null;_error=null;}
  Future<void> pick(bool departure) async {
    final old=departure?_departure:_arrival;
    final date=await showDatePicker(context:context,initialDate:DateTime(old.year,old.month,old.day),firstDate:DateTime(2000),lastDate:DateTime(2100,12,31));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay(hour:old.hour,minute:old.minute),builder:(c,w)=>MediaQuery(data:MediaQuery.of(c).copyWith(alwaysUse24HourFormat:true),child:w!));
    if(time==null||!mounted)return;
    setState((){final value=DateTime.utc(date.year,date.month,date.day,time.hour,time.minute);if(departure){_departure=value;}else{_arrival=value;}invalidate();});
  }
  Widget field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:18),child:TextFormField(controller:c,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState(invalidate),validator:(s)=>number(s??'')==null||number(s??'')!<=0?'Enter a positive number.':null));
  void calculate(){if(!_form.currentState!.validate())return;try{final r=EcoSpeedPlan.calculate(distance:number(_distance.text)!,ecoSpeed:number(_eco.text)!,fullSpeed:number(_full.text)!,departure:_departure,arrival:_arrival);setState((){_result=r;_error=null;});}on FormatException catch(e){setState((){_result=null;_error=e.message;});}}
  Widget modeResult(String title,double hours,double distance)=>Container(margin:const EdgeInsets.only(top:14),padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFF112437),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Color(0xFF4DDAC6),fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text('${hours.toStringAsFixed(4)} hours'),Text('${(hours/24).toStringAsFixed(4)} days'),Text(etaDuration(Duration(microseconds:(hours*3600000000).round()))),const SizedBox(height:8),Text('${distance.toStringAsFixed(2)} NM')]));
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF081522),appBar:AppBar(title:const Text('Eco / Full Speed')),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('Plan how long to sail at Eco Speed and Full Speed to cover the remaining distance and arrive at the target time.',style:TextStyle(fontSize:18,height:1.5)),
    const SizedBox(height:10),const Text('Enter average speeds over ground (SOG). All dates and times below are UTC. Stops and waiting time are not included.',style:TextStyle(color:Color(0xFF9BB0C3),height:1.5)),const SizedBox(height:24),
    Form(key:_form,child:Column(children:[field(_distance,'Distance / Remaining Distance (NM)'),field(_eco,'Eco Speed (kts)'),field(_full,'Full Speed (kts)')])),
    OutlinedButton.icon(onPressed:()=>pick(true),icon:const Icon(Icons.calendar_month),label:Text('Departure Time (UTC)\n${etaDateTime(_departure)}')),
    TextButton(onPressed:(){final n=DateTime.now().toUtc();setState((){_departure=DateTime.utc(n.year,n.month,n.day,n.hour,n.minute);invalidate();});},child:const Text('Use Current Time')),
    OutlinedButton.icon(onPressed:()=>pick(false),icon:const Icon(Icons.calendar_month),label:Text('Target Arrival (UTC)\n${etaDateTime(_arrival)}')),
    const SizedBox(height:14),Text('Available time: ${(_arrival.difference(_departure).inMinutes/60).toStringAsFixed(2)} hours'),const SizedBox(height:20),
    FilledButton(onPressed:calculate,child:const Padding(padding:EdgeInsets.all(16),child:Text('Calculate Eco / Full Speed'))),
    if(_error!=null)Padding(padding:const EdgeInsets.only(top:18),child:Text(_error!,style:const TextStyle(color:Colors.amber,height:1.5))),
    if(_result!=null)...[modeResult('Eco Speed',_result!.ecoHours,_result!.ecoDistance),modeResult('Full Speed',_result!.fullHours,_result!.fullDistance),const SizedBox(height:18),Text('Total: ${_result!.totalHours.toStringAsFixed(4)} hours / ${(_result!.totalHours/24).toStringAsFixed(4)} days'),Text('Target arrival: ${etaDateTime(_arrival)} UTC'),const SizedBox(height:12),const Text('The result gives the total time in each mode. It does not prescribe which mode to use first.',style:TextStyle(color:Color(0xFF9BB0C3),height:1.5))],
  ])))));
}
