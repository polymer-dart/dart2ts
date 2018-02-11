@JS()
library polymer;

import 'mini_html.dart';
import 'package:js/js.dart';
import 'package:dart2ts/annotations.dart';

@JS()
@TS(generate: true, export: '../node_modules/@polymer/polymer/polymer-element')
class Element extends HTMLElement {}

@JS()
@TS(generate: true)
external HTMLTemplateElement html(List<String> literals, @varargs List values);
