class WithOperand {
  operator+(WithOperand another) {
    return new WithOperand();
  }
}

class SubClass extends WithOperand {

}

doSomeOps() {
  WithOperand a = new WithOperand(),b = new WithOperand();

  WithOperand c = a + b;

  int d = 5, e = 5;
  int f = d + e;

  return new SubClass() + new SubClass();
}