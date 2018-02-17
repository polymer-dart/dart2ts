class TestClass {
  List<TestClass> children = [];

  void doSomething() {
    TestClass t = new TestClass();
    children.add(t);
    children.remove(t);
  }
}