import 'dart:async';

testDaStream() async {
  startStream1(StreamController controller) async {
    for (int i = 0; i < 10; i++) {
      controller.add("Event ${i}");
      await new Future.delayed(new Duration(milliseconds: 50));
    }
    controller.close();
  }

  startStream2(StreamController controller) async {
    for (int i = 0; i < 10; i++) {
      await new Future.delayed(new Duration(milliseconds: 50));
      controller.add("Event ${i}");
    }
    controller.close();
  }

  await execStreamOnListen(startStream1);

  await execStream(startStream1);

  await execStream(startStream2);

  await execStream(startStream1, 5);

  await execStream(startStream2, 5);



  // Now with onListen
}

Future execStreamOnListen<X>(void source(StreamController<X> c), [int max]) async {
  StreamController controller =
      new StreamController.broadcast(onListen: () => source(controller), onCancel: () => print('CANCEL'));

  print('start receiving');
  await for (String event in controller.stream) {
    print("Received : ${event}");
    if (max != null) {
      if (max-- <= 0) {
        break;
      }
    }
  }
  print('finished receiving');
}

Future execStream<X>(void source(StreamController<X> c), [int max]) async {
  StreamController controller = new StreamController.broadcast();
  source(controller);

  print('start receiving');
  await for (String event in controller.stream) {
    print("Received : ${event}");
    if (max != null) {
      if (max-- <= 0) {
        break;
      }
    }
  }
  print('finished receiving');
}
