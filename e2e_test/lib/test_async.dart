part of 'sample1.dart';

Future<List<int>> testAsync() =>
    Future.wait(new List.generate(5, (i) => new Future.delayed(new Duration(seconds: i), () => i)));


testAwait() async =>
  [0,1,2,3,4] == await testAsync();
