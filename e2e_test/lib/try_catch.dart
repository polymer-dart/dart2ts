int doSomethingBadFinally = 0;

doSomethingBad(String str) {
  try {
    return "${str.length}";
  } on NullThrownError catch (e) {
    return e.toString();
  } catch (error, stack) {
    return "${error}:${stack}";
  } finally {
    doSomethingBadFinally++;
  }
}

int doSomethingElseNoCatchFinally = 0;
doSomethingElseNoCatch(String str) {
  try {
    return str.length;
  } on NullThrownError {
    return -1;
  } catch (rest) {
    return -2;
  } finally {
    doSomethingElseNoCatchFinally++;
  }

}
