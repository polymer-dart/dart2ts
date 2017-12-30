class SomeClass {
  SomeClass parent;
  String field;
}

doSomething() {
  SomeClass a = new SomeClass();
  SomeClass b = new SomeClass();

  String f = a.parent.parent.field;

  String g = a.field;

  var c = a;

  String f1 = c.parent.parent.field;

  String g1 = c.field;

  SomeClass x = new SomeClass()
    ..parent = (new SomeClass()..field = "pippo")
    ..field = "pluto";
}
