import 'package:js/js.dart';

@JS()
external void alert(String);


@JS()
external
class
Document
{
Element get body;
HTMLDivElement createElement(String div);
}

@JS()
external Document document;


@JS
()
external class Element
{
void appendChild(Element e);
}

@JS()
external class HTMLDivElement extends Element
{
String innerHTML;
}


void printToBody(String message) => document.body.appendChild(document.createElement('div')
..innerHTML=message);