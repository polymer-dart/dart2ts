void sayHello(String msg) {
  print(msg);
}

class AnotherClass {
  AnotherClass({String named,int num}) {
    print('parent :${named} , ${num}');
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

  void sayIt2(String msg,[num pippo=-1]) {
    sayHello(msg);
  }

  void sayItWithNamed(String arg,{String other:'ops',int x}) {
    print("${arg} : ${other}, x: ${x}");
  }
}

class MySampleClass2 extends AnotherClass {
  MySampleClass2([int optInd=5]) : super.other('x') {
    print("OPTIND:${optInd}");
  }

  MySampleClass2.extra({String namedOnNamed:'withDefault'}) : super(named:namedOnNamed,num:42) {
    print("NAMED ON NAMED: ${namedOnNamed}");
  }
}

MySampleClass1 createSampleClass1() => new MySampleClass1();
MySampleClass1 createSampleClass2(String x) => new MySampleClass1.another(x);