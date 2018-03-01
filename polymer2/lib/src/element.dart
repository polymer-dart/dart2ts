@JS('Polymer')
library polymer2.lib.src.element;

import 'package:html5/html.dart';
import 'package:js/js.dart';
import 'package:polymer2/src/annotations.dart';
import 'package:dart2ts/annotations.dart';
import 'dart:async';
import 'html_import.dart';

@JS()
@TS(generate: true)
@BowerImport(ref: 'polymer#2.0.0', name: 'polymer', import: 'polymer/polymer_element.html')
abstract class Element extends HTMLElement {
  get(String path);

  set(String path, value);

  notifyPath(String path);
}

List<Future> _allFutures = [];

@onModuleLoad
_importHtml() {
  _allFutures.add(importHtml('bower_components/polymer/polymer_element.html'));
}

Future get polymerReady => Future.wait(_allFutures);
