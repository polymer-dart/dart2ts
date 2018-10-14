import 'dart:async';

/**
 * export var doAsync: () => any = () => new async.Future.fromPromise((async (): Promise<any> => {
    let result: string = await (() => new async.Future.fromPromise((async (): Promise<any> => {
    return "hi";
    })()))();
    return result;
    })());
 */
doAsync(String salute, String name) async {
  String result = await ((String name) async {
    return "${salute} ${name}";
  })(name);

  return result;
}

Stream<String> doAsyncStream(String name) {
  String salute = "Hi";
  return ((String name) async* {
    for (int i = 0; i < 3; i++) {
      await new Future.delayed(new Duration(seconds: 1));
      yield await doAsync(salute, name);
    }
  })(name);
}

testStream() {
  return doAsyncStream("Jhon").join(',');
}
