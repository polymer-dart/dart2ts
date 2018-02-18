class MyClass {

}

class MyOtherClass {

}


void doSomethingWith() {

  Expando<MyClass> exp = new Expando();

  MyOtherClass other = new MyOtherClass();

  exp[other] = new MyClass();

  MyClass val = exp[other];

}