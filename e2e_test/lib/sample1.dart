import 'sample2.dart' as xy;

void main(List<String> args) {
  xy.sayHello('Hello Dart2TS');

  ciao(String x) {
    xy.sayHello(x);
  }

  ciao(((String x) => (String y) {
    return (z) => "$x $y $z";
  })('Hello')('world')('Mario'));

  print('bye!');
}

