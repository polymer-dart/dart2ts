import 'dart:async';

testFuture() async {
  await simpleAsyncFunc();
}

Future<bool> simpleAsyncFunc() async {
  await new Future.delayed(new Duration(seconds: 1));
  return true;
}