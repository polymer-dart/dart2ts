import 'dart:async';
import 'sample3.dart';

Future testFuture() async {
  await simpleAsyncFunc();
}

Future<bool> simpleAsyncFunc() async {
  await new Future<any>.delayed(new Duration(seconds: 1));
  return true;
}

Stream<int> simpleAsyncStreamFunc() async* {
  for (int i = 0; i < 5; i++) {
    await new Future<any>.delayed(new Duration(milliseconds: 500));
    yield i;
  }
}

Future cips() async {
  await for (String x in simpleAsyncStreamFunc().map((x) => 'Num ${x}')) {
    printToBody(x);
  }
}
