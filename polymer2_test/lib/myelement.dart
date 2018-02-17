import 'html_template.dart';
import 'mini_html.dart';
import 'package:dart2ts/annotations.dart';
import 'package:html5/html.dart';
import 'polymer.dart' as polymer;

class MyElement extends HTMLElement {
  String name;
  int number = 0;

  MyElement() {
    name = "Pino" " Daniele " "Lives!";
  }

  void changeName(ev, detail) {
    print('Clicked : ${ev}, ${detail}');
    //number = number + 1;
    name = 'Super app : ${number++}';
  }
}

@onModuleLoad
void _registerElements() {
  customElements.define('my-tag', MyElement);
}
