void main(List<String> args) {
  sayHello('Hello Dart2TS');

  print(((String x) => (String y) {
    return (z) => "$x $y $z";
  })('Hello')('world')('Mario'));

}

void sayHello(String msg) {
  print(msg);
}
