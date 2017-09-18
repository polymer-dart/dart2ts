void sayHello(String msg) {
  print(msg);
}

class MySampleClass1 {
  MySampleClass1() {
    print('hi man!');
  }

  void sayIt(String msg) => sayHello(msg);

  void sayIt2(String msg) {
    sayHello(msg);
  }
}

MySampleClass1 createSampleClass1() => new MySampleClass1();
