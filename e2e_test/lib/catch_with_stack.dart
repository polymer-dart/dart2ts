doSomething() {
  try {
    throw "error";
  } catch (error, stack) {
    print("ERORR:${error}, stack:${stack}");
  }
}