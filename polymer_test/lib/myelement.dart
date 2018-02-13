import 'html_template.dart';
import 'mini_html.dart';
import 'polymer.dart' as polymer;

class MyElement extends polymer.Element {
  String name;

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

  void changeName(ev,detail) {
    print('Clicked : ${ev}, ${detail}');
    name='Super app'
  }
}

void main() {
  customElements.define('my-tag', MyElement);
  print("hello");
}

// 4. long string check
