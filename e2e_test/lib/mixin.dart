class Mixin {
  String sayHello(String to) => "Hello ${to}!";
}

class MyClass extends Object with Mixin  {
  selfHello() {
    sayHello("Me");
  }
}

class AnotherClass extends MyClass with Mixin {
  String sayHello(String to) => "Ciao ${to}";
  selfHello() {
    sayHello("Me");
  }
}