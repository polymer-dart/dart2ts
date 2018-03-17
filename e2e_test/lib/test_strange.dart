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
