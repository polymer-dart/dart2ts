import 'mini_html.dart';
import 'package:dart2ts/annotations.dart';
import 'polymer.dart' as polymer;

@TS(stringInterpolation: true)
HTMLTemplateElement html(String template, {List<String> literals, List values}) {
  return polymer.html(literals, values);
}