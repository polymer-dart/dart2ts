import 'sample2.dart' as xy;

void main(List<String> args) {
  xy.sayHello('Hello Dart2TS');

  ciao(String x) {
    xy.sayHello(x);
  }

  print(args.map((x) => "[${x}]").join(','));
  print('\n');

  int n = 5;
  n = ((n + 4) * 2) ^ 3;
  List<int> values = [n];

  print("Result : ${values[0]}");

  String c = "wow!";

  ciao(((String x) => (String y) {
        return (z) => "${c} $x $y $z";
      })('Hello')('world')('Mario'));

  new xy.MySampleClass1().sayIt('once');

  xy.MySampleClass1 other = new xy.MySampleClass1();
  other.sayIt2('twice');

  xy.createSampleClass1().sayIt('final');

  xy.createSampleClass2('ugo').sayIt2('picio');

  new xy.MySampleClass1.another('ugo2').sayIt('ugo2 says');

  new xy.MySampleClass2();

  new xy.MySampleClass2.extra();

  print('bye!');
}
