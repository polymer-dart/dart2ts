import 'function_declaration.dart' as func;

class SomeClass {
  String name;
  int ord = 4;
  String message = "no msg";

  SomeClass(this.name, {this.ord}) {
    message = "Ciao ${name} [${ord}]";
  }

  SomeClass.withName(String name, {int ord1}) : this(name, ord: 5 + ord1);

  SomeClass.withOrg(int ord) : this.withName('org');

  factory SomeClass.noRemorse() => new SomeClass.withName("No repent");
}

class DerivedClass extends SomeClass {
  DerivedClass() : super.withName('pippo', ord1: 100);

  DerivedClass.withName() : super.withOrg(1000) {
    message = "Overridden";
  }
}

class Derived1 extends SomeClass {
  factory Derived1() {
    return new Derived1._();
  }

  Derived1._() : super('der1');
}

class Derived2 extends Derived1 {
  factory Derived2() {
    return new Derived2._();
  }

  Derived2._() : super._();
}

class Generic1<X> extends SomeClass {
  X x1;
  factory Generic1(X x1) {
    return new Generic1.named(x1);
  }

  Generic1.named(this.x1) : super.withOrg(10);

  factory Generic1.named2(X x2) {
    return new Generic1<X>.named(x2);
  }

  factory Generic1.named3(X x3) {
    return new Generic1<X>(x3);
  }
}

void useEm() {
  SomeClass x = new SomeClass('hi', ord: 5);

  SomeClass y = new SomeClass.withName('bye');

  SomeClass z = new SomeClass.withOrg(5);

  SomeClass w = new SomeClass.noRemorse();

  Derived1 d1 = new Derived1();

  Derived2 d2 = new Derived2();

  Generic1<bool> g1 = new Generic1(true);

  Generic1<String> g2 = new Generic1<String>.named3('hello');

  List<SomeClass> abcd = <SomeClass>[x, y, z, w, d1, d2];
}

void useTopFromAnother() {
  func.topLevelSetter = useEm;

  func.topLevelVar = useEm;

  func.topLevelVar();

  func.topLevelSetter();

  print("F1 :${func.topLevelSetter}, F2: ${func.topLevelVar}");
}
