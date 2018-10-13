abstract class MyInterface<X> {
  X get x;

  factory MyInterface(X val) = MyImpl<X>;

  factory MyInterface.named({X x}) = MyImpl<X>.named;
}

class MyImpl<Y> implements MyInterface<Y> {
  Y x;

  @override
  MyImpl(Y val) {
    this.x = val;
  }

  MyImpl.named({this.x}) {}
}

int test1(int val) {
  return new MyInterface(val).x;
}

int test2(int val) {
  return new MyInterface.named(x: val).x;
}

String test3() {
  String x = "value1";

  x ??= "value2";

  return x;
}

int test4(y) {
  return (y?.length) ?? -1;
}

int test5(y) {
  return ((y?.toString() as dynamic)?.length) ?? -1;
}

class Pippo {
  doNothing() {}

  Pippo getParent() => null;

  String doHello(String name) => "Hello ${name}";
}

String test6(Pippo p, String name) {
  return p?.doHello(name);
}

String test7(Pippo p, String name) {
  return p?.getParent()?.doHello(name);
}
