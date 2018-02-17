import 'html_template.dart';
import 'mini_html.dart';
import 'package:dart2ts/annotations.dart';
import 'polymer.dart' as polymer;

class MyElement extends polymer.Element {
  String name;
  int number = 0;

  static get template => html("""
  <style>
    .btn {
      display:inline-block;
      padding:1em;
      margin:1em;
      background-color: lightblue;
      cursor: pointer;
    }
  </style>
<div>
 This is my '[[name]]' app.
 <div class='btn' on-click='changeName'>Click here Please</div>
</div>
""");

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
