class MyClass<X> {
  int _num;

  String Function(String x, String y) _handler;

  MyClass(this._num, [String Function(String x, String y) h]) {
    testCallingNamed(handler: h ?? _aMethod);

    callingStatic(_aMethod);
  }

  String _aMethod(String x, String y) {
    return "Method ${x} ${y} - ${_num}";
  }

  void testCallingNamed({String Function(String x, String y) handler}) {
    _handler = handler;
  }

  static callingStatic({String Function(String x, String y) handler}) {}

  String doSomethingWith(String Function(String x, String y) proc, String x) => proc(x, ' or not?');

  void testMethodRef() {
    print(doSomethingWith(_handler, 'Works?'));
  }
}
