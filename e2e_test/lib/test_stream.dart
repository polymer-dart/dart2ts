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

  await execStream(startStream1);

  await execStream(startStream2);
}


Future execStream<X>(void source(StreamController<X> c)) async {
  StreamController controller = new StreamController.broadcast();
  source(controller);

  print('start receiving');
  await for (String event in controller.stream) {
    print("Received : ${event}");
  }
  print('finished receiving');
}