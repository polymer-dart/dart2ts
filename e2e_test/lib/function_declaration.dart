bool boolFunction(int arg) {
  return null;
}

int intFunction(int arg,[int opt,int opt2=4]) {
  return 5;
}

String stringFunction(int arg,{int named,int named2:4}) {
  return "Hello Jhonny!";
}

varFunction(String nornalArg, [int optionalArg]) {
  return null;
}

void voidFunction(normalArg, {String namedArgument}) {

}

List<E> genericFunction<E>() {
  return null;
}

set topLevelSetter(Function f) {

}

functionInsideFunctions() {
  insideIt(x) {
    return 10;
  }

  var anotherFunc = (y) {
    return y + 1;
  }

  var anotherFunc2;

  anotherFunc2 = () => "hi";

  topLevelSetter = () => "bad";

  var someClosure = (x) => 10;

  return insideIt;
}