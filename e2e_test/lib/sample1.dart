import 'sample2.dart' as xy;
import 'package:js/js.dart';
import 'sample3.dart';
import 'sample4.dart';

void main(List<String> args) {
  printToBody("<h1>GOOD MOOOOOOOOOOOOOOOORNING DART2TS!!</h1>");
  xy.sayHello('Hello Dart2TS');

  printToBody("<b>DOC!</b> : ${document.body}");

  HTMLDivElement e = document.createElement('div')..innerHTML = 'ciao ciao dart 2ts!!';
  document.body.appendChild(e);

  ciao(String x) {
    xy.sayHello(x);
  }

  printToBody(args.map((x) => "[${x}]").join(','));
  printToBody('\n');

  int P = [0].first;
  int n = 5;
  n = ((n + 4) * 2) ^ 3;
  List<int> values = [n];

  printToBody("Result ${P} : ${values[0]} len : ${values.length}");

  int x = [0].first + (values).first;

  printToBody("Result FIRST! : ${values.first}");

  String c = "wow!";

  ciao(((String x) => (String y) {
        return (z) => "${c} $x $y $z";
      })('Hello')('world')('Mario'));

  new xy.MySampleClass1().sayIt('once');

  xy.MySampleClass1 other = new xy.MySampleClass1();
  other.sayIt2('twice');

  xy.createSampleClass1().sayIt('final');

  xy.createSampleClass2('ugo').sayIt2('picio', 5);

  xy.MySampleClass1 a = xy.createSampleClass2('ciro')
    ..sayItWithNamed('some', x: 5, other: 'oth')
    ..sayItWithNamed('thing', x: 4)
    ..sayItWithNamed('has', other: 'uuu')
    ..sayItWithNamed('changed');

  printToBody("A = ${a.title} , ${a.otherField}");

  a.otherField = a;

  printToBody("U : ${a.otherField.otherField.title}");

  a.theTitle = 'jungle';
  printToBody("CHANGED : ${a.title}");

  new xy.MySampleClass1.another('ugo2').sayIt('ugo2 says');

  new xy.MySampleClass2();

  new xy.MySampleClass2.extra();

  new xy.MySampleClass2.extra(namedOnNamed: (1 == 1) ? 'django' : 'tango');

  new xy.MakeItReal();

  printToBody('bye!');

  testFuture().then((_) {
    printToBody("Future works");
  });
}
