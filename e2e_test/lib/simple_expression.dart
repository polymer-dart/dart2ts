import 'dart:math' as m;

class SomeClass {
  SomeClass parent;
  String field;
  String get otherField => "pippo";
  void set otherField(String value) {}

  implicitThis(String val) {
    String prev = field + otherField;
    field=val;
    otherField = val;


    return prev;
  }
}

class Derived extends SomeClass {
  implicitThis2(String val) {
    String prev = field + otherField;
    field=val;
    otherField = val;


    return prev;

  }
}

doSomething() {
  // Normal property access
  SomeClass a = new SomeClass();
  SomeClass b = new SomeClass();

  String f = a.parent.parent.field;

  String g = a.field;
  String h = a.otherField;

  var c = a as dynamic;

  // Prefixed expre that's not a property
  var d = m.E;

  // unknown property access
  String f1 = c.parent.parent.field;

  String g1 = c.field;

  // Cascading
  SomeClass x = new SomeClass()
    ..parent = (new SomeClass()..field = "pippo")
    ..parent.field = "Fino"
    ..otherField = "ciccio"
    ..field = "pluto";

  // Cascading with unknown
  var y = (x as dynamic)
    ..parent = (new SomeClass()..field = "pippo")
    ..parent.field = "pino"
    ..otherField = "brook"
    ..field = "pluto";
}
