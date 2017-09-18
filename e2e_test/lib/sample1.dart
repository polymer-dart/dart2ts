import 'sample2.dart' as xy;

void main(List<String> args) {
  xy.sayHello('Hello Dart2TS');

  ciao(String x) {
    xy.sayHello(x);
  }

  String c="wow!";

  ciao(((String x) => (String y) {
        return (z) => "${c} $x $y $z";
      })('Hello')('world')('Mario'));

  new xy.MySampleClass1().sayIt('once');

  xy.MySampleClass1 other = new xy.MySampleClass1();
  other.sayIt2('twice');

  xy.createSampleClass1().sayIt('final');

  print('bye!');
}
