import 'dart:async';

class AsyncMethods {
  Future<String> delayedString(String arg) async {
    await new Future.delayed(new Duration(seconds: 1));
    return arg;
  }

  static delayedStaticString(String arg) async {
    await new Future.delayed(new Duration(seconds: 1));
    return arg;
  }

  delayedStream(int n, String arg) async* {
    for (int i = 0; i < n; i++) {
      String res = await delayedString(arg);
      yield res;
    }
  }

  static delayedStaticStream(int n, String arg) async* {
    for (int i = 0; i < n; i++) {
      String res = await delayedStaticString(arg);
      yield res;
    }
  }

  // And generators too
  generator(int n, String arg) sync* {
    for (int i = 0; i < n; i++) {
      yield arg;
    }
  }

  static staticGenerator(int n, String arg) sync* {
    for (int i = 0; i < n; i++) {
      yield arg;
    }
  }
}

generatorFunction(int n, String arg) sync* {
  for (int i = 0; i < n; i++) {
    yield arg;
  }
}

delayedStreamFunction(int n, String arg) async* {
  for (int i = 0; i < n; i++) {
    String res = await delayedStringFunction(arg);
    yield res;
  }
}

delayedStringFunction(String arg) async {
  await new Future.delayed(new Duration(seconds: 1));
  return arg;
}

useThat(String seed) async {
  AsyncMethods asyncMethods = new AsyncMethods();
  for (String cuc in generatorFunction(5, seed)) {
    await for (String ciup in delayedStreamFunction(5, cuc)) {
      for (String str in AsyncMethods.staticGenerator(5, ciup)) {
        for (String cip in asyncMethods.generator(5, str)) {
          await for (String pip in AsyncMethods.delayedStaticStream(5, cip)) {
            await for (String tri in asyncMethods.delayedStream(5, pip)) {
              print("Result static: ${await AsyncMethods.delayedStaticString(tri)}");
              print("Result : ${await asyncMethods.delayedString(tri)}");
              print("Result func: ${await delayedStringFunction(tri)}");
            }
          }
        }
      }
    }
  }
}
