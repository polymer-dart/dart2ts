void sayHello(String msg) {
  print(msg);
}

class AnotherClass {
  AnotherClass() {
    print('parent');
  }

  AnotherClass.other(String x) {
    print('parent other ${x}');
  }
}

class MySampleClass1 extends AnotherClass {
  MySampleClass1() : super() {
    print('hi man!');
  }


  MySampleClass1.another(String who) : super.other('XX${who}xx') {
    print('Yo ${who}');
  }

  void sayIt(String msg) => sayHello(msg);

  void sayIt2(String msg) {
    sayHello(msg);
  }
}

class MySampleClass2 extends AnotherClass {
  MySampleClass2() : super.other('x') {

  }

  MySampleClass2.extra() : super() {

  }
}

MySampleClass1 createSampleClass1() => new MySampleClass1();
MySampleClass1 createSampleClass2(String x) => new MySampleClass1.another(x);