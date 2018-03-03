import 'package:dart2ts/annotations.dart';
import 'package:html5/html.dart';
import 'package:polymer2/polymer2.dart' as polymer;
import 'package:polymer2/src/polymer_support.dart' as polymer2 show register;
import 'package:js/js.dart';

@polymer.PolymerRegister('my-tag', template: 'myelement.html')
abstract class MyElement extends polymer.Element {
  String name;
  int number = 0;

  //@JS('is')
  //static String _tagName = 'my-tag';

  MyElement() {
    name = "Pino" " Daniele " "Lives!";
  }

  void changeName(Event ev, detail) {
    ev.preventDefault();
    ev.stopPropagation();
    print('Clicked : ${ev}, ${detail}');
    //number = number + 1;
    name = 'Super app : ${number++}';
  }
}

@onModuleLoad
void _registerElements() {
  polymer2.register(MyElement, 'my-tag');
  //window.customElements.define('my-tag', MyElement);
}
