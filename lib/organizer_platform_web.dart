// Browser APIs are isolated here so other Flutter targets can still compile.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class DeckOrganizerScreen extends StatefulWidget {
  const DeckOrganizerScreen({super.key});
  @override
  State<DeckOrganizerScreen> createState()=>_DeckOrganizerScreenState();
}
class _DeckOrganizerScreenState extends State<DeckOrganizerScreen> {
  static int _counter=0;
  late final String _view;
  late final html.IFrameElement _frame;
  Timer? _timer;
  StreamSubscription<html.Event>? _subscription;
  bool _loading=true;
  bool _slow=false;
  @override
  void initState(){
    super.initState();
    _view='deck-organizer-${_counter++}';
    final base=Uri.parse(html.document.baseUri ?? html.window.location.href);
    _frame=html.IFrameElement()
      ..src=base.resolve('deck-organizer/index.html').toString()
      ..title='Deck Organizer'
      ..setAttribute('allow','camera')
      ..style.border='0'
      ..style.width='100%'
      ..style.height='100%';
    _subscription=_frame.onLoad.listen((_){_timer?.cancel();if(mounted)setState(()=>_loading=false);});
    _timer=Timer(const Duration(seconds:15),(){if(mounted)setState(()=>_slow=true);});
    ui_web.platformViewRegistry.registerViewFactory(_view,(_)=>_frame);
  }
  @override
  void dispose(){_timer?.cancel();_subscription?.cancel();_frame.src='about:blank';_frame.remove();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF081522),
    appBar: AppBar(title: const Text('Deck Organizer')),
    body:Stack(children:[Positioned.fill(child:HtmlElementView(viewType:_view)),
      if(_loading)Positioned.fill(child:IgnorePointer(child:ColoredBox(color:const Color(0xFF081522),child:Center(child:_slow
        ? const Text('Still loading. Check web/deck-organizer installation, then restart Flutter.')
        : const CircularProgressIndicator())))),
    ]),
  );
}
