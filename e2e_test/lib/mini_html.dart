@JS()
library mini_html;

import 'package:js/js.dart';

@JS('window')
external Window get window;

@JS('document')
external Document get document;

@JS("Window")
abstract class Window {
  external void alert(String msg);
  external void scroll(num x,num y);
}

@JS("Element")
abstract class Element implements Node {}

@JS("HTMLElement")
abstract class HTMLElement implements Element {}

@JS("Node")
abstract class Node {
  external appendChild(Node node);
}

@JS("Document")
abstract class Document {
  external HTMLElement createElement(String tagName);
}

HTMLElement createDiv() => document.createElement('div');