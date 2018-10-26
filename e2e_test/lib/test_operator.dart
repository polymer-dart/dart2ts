testSomeOps() {
  bool a = false;

  var b;
  if (!a) {
    b=false;
  } else {
    b=true;
  }

  if (!b) {
    return 10;
  } else {
    return 20;
  }
}