class SomeClass {
  String name;
  int ord=4;
  String message="no msg";

  SomeClass(this.name, {this.ord}) {
    message = "Ciao ${name} [${ord}]";
  }

  SomeClass.withName(String name,{int ord1}) : this(name, ord: 5+ord1);

  SomeClass.withOrg(int ord) : this.withName('org'), ord = ord {
    message="${ord} hi";
  }

  factory SomeClass.noRemorse() => new SomeClass.withName("No repent");
}

void useEm() {
  SomeClass x = new SomeClass('hi',ord:5);

  SomeClass y = new SomeClass.withName('bye');

  SomeClass z = new SomeClass.withOrg(5);

  SomeClass w = new SomeClass.noRemorse();

  List<SomeClass> abcd = [x,y,z,w];
}