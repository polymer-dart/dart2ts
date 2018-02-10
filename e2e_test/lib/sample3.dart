import 'package:js/js.dart';

@JS()
external void alert(String);

@JS()
class Document {
  Element get body;

  Element createElement(String div);
}

@JS()
external Document get document;

@JS()
class Element {
  String innerHTML;

  void appendChild(Element e);
}

@JS()
class HTMLDivElement extends Element {}

@JS()
class HTMLSpanElement extends Element {}

void printToBody(String message) {
  print(message);
  document.body.appendChild(document.createElement('div')..innerHTML = message);
}
