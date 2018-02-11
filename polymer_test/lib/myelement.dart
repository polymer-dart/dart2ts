import 'html_template.dart';
import 'mini_html.dart';
import 'polymer.dart' as polymer;

class MyElement extends polymer.Element {
  String name;

  static get template => html("""
<div>
 This is my [[name]] app.
</div>
""");

  MyElement() {
    name = "Pino" " Daniele " "Lives!";
  }
}

void main() {
  customElements.define('my-tag', MyElement);
  print("hello");
}

// 4. long string check
