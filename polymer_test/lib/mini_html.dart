import 'package:js/js.dart';

@JS()
class CustomElementRegistry {
  external define(String tag, elementClass);
}

@JS()
class HTMLElement {

}

@JS()
external CustomElementRegistry get customElements;

@JS()
class HTMLTemplateElement {

}
