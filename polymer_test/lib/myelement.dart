import 'mini_html.dart';
import 'package:dart2ts/annotations.dart';
import 'polymer.dart' as polymer;

@TS(stringInterpolation: true)
HTMLTemplateElement HTML(String template, {List<String> literals, List values}) {
  return polymer.html(literals, values);
}

class MyElement extends polymer.Element {
  String name;

  static get template => HTML("""
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
