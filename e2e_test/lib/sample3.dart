import 'package:js/js.dart';

@JS()
external void alert(String);

@JS()
class Document {
  Element get body;
  HTMLDivElement createElement(String div);
}

@JS()
external Document get document;

@JS()
class Element {
  void appendChild(Element e);
}

@JS()
class HTMLDivElement extends Element {
  String innerHTML;
}

void printToBody(String message) {
  print(message);
  document.body.appendChild(document.createElement('div')..innerHTML = message);
}
