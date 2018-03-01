@JS('Polymer')
library polymer2.lib.src.element;

import 'package:html5/html.dart';
import 'package:js/js.dart';
import 'package:polymer2/src/annotations.dart';
import 'package:dart2ts/annotations.dart';
import 'dart:async';

@JS()
@TS(generate: true)
@BowerImport(
    ref: 'polymer#2.5.0', name: 'polymer', import: 'polymer/polymer.html')
abstract class Element extends HTMLElement {
  get(String path);

  set(String path, value);

  notifyPath(String path);
}
