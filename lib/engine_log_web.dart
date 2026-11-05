// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class EngineLogScreen extends StatelessWidget {
  const EngineLogScreen({super.key});

  static const _viewType = 'engine-log-frame';
  static final _registered = ui_web.platformViewRegistry.registerViewFactory(
    _viewType,
    (int viewId) {
      final base = Uri.parse(
        html.document.baseUri ?? html.window.location.href,
      );
      return html.IFrameElement()
        ..src = base.resolve('engine-log/index.html').toString()
        ..title = 'EngineLog'
        ..setAttribute('allow', 'clipboard-write')
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Engine')),
    body: _registered
        ? const HtmlElementView(viewType: _viewType)
        : const Center(child: Text('Could not open EngineLog.')),
  );
}
