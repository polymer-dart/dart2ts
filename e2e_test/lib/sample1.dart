import 'sample2.dart' as xy;

void main(List<String> args) {
  xy.sayHello('Hello Dart2TS');

  ciao(String x) {
    xy.sayHello(x);
  }

  print(args.map((x) => "[${x}]").join(','));
  print('\n');

  int P = [0].first;
  int n = 5;
  n = ((n + 4) * 2) ^ 3;
  List<int> values = [n];

  print("Result ${P} : ${values[0]} len : ${values.length}");

  int x = [0].first + (values).first;

  print("Result FIRST! : ${values.first}");

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

  new xy.MySampleClass1.another('ugo2').sayIt('ugo2 says');

  new xy.MySampleClass2();

  new xy.MySampleClass2.extra();

  new xy.MySampleClass2.extra(namedOnNamed: (1==1)?'django':'tango');

  new xy.MakeItReal();

  print('bye!');
}
