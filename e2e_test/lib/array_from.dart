void doSomething() {
  List<String> str = new List.from((() sync* {
    yield "Hello";
    yield "world";
  })());

  print("Strings : ${str}");
}
