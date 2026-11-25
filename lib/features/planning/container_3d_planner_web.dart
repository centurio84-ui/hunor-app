import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

@JS('document.createElement')
external _DomElement _createElement(String tagName);

extension type _DomStyle(JSObject _) implements JSObject {
  external set width(String value);
  external set height(String value);
  external set border(String value);
  external set display(String value);
  external set overflow(String value);
}

extension type _DomWindow(JSObject _) implements JSObject {
  external void postMessage(JSAny? message, String targetOrigin);
}

extension type _DomElement(JSObject _) implements JSObject {
  external set src(String value);
  external _DomStyle get style;
  external _DomWindow? get contentWindow;
  external void setAttribute(String name, String value);
}

int _nextPlannerViewId = 0;

class Container3DPlannerTabImpl extends StatefulWidget {
  const Container3DPlannerTabImpl({super.key});

  @override
  State<Container3DPlannerTabImpl> createState() =>
      _Container3DPlannerTabImplState();
}

class _Container3DPlannerTabImplState extends State<Container3DPlannerTabImpl> {
  late final String _viewType;
  _DomElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewType = 'hunor-3d-container-planner-${++_nextPlannerViewId}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = _createElement('iframe')
        ..src = '3d_container_planner.html'
        ..setAttribute('allow', 'accelerometer; gyroscope')
        ..setAttribute('title', '3D Konténerváz tervező');
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none'
        ..display = 'block'
        ..overflow = 'hidden';
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void dispose() {
    final iframe = _iframe;
    _iframe = null;
    if (iframe != null) {
      try {
        final payload = <String, Object?>{'type': 'DISPOSE_3D_PLANNER'}.jsify();
        iframe.contentWindow?.postMessage(payload, '*');
      } catch (_) {}
      try {
        iframe.src = 'about:blank';
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
