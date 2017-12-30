import 'dart:math' as m;

class SomeClass {
  SomeClass parent;
  String field;
}

doSomething() {

  // Normal property access
  SomeClass a = new SomeClass();
  SomeClass b = new SomeClass();

  String f = a.parent.parent.field;

  String g = a.field;

  var c = a as dynamic;

  // Prefixed expre that's not a property
  var d = m.E;

  // unknown property access
  String f1 = c.parent.parent.field;

  String g1 = c.field;

  // Cascading
  SomeClass x = new SomeClass()
    ..parent = (new SomeClass()..field = "pippo")
    ..field = "pluto";

  // Cascading with unknown
  var y = (x as dynamic)
    ..parent = (new SomeClass()..field = "pippo")
    ..field = "pluto";
}
