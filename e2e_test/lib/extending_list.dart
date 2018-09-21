import 'dart:collection';

/**
 * TODO : Investigate Change operator "[]" overriding implementation using ES6 proxies.
 * This will allow the use of List and Maps with operator "[]” in a seamless way.
 *
 * Otherwise: we have to take into account dart annotations as well as ovverides.yml when choosing the
 * operator translation.
 *
 * TODO: Fix the logic that does class overrides to stop at the first class
 *
 */

/**
 * Extending iterable test
 */

class MyIterable<X> extends Iterable<X> {
  X _x;

  MyIterable(this._x);

  @override
  Iterator<X> get iterator => new MyIterator<X>(_x);
}

class MyIterator<X> extends Iterator<X> {
  X _x;
  int _count;

  MyIterator(this._x) : _count = 0;

  @override
  X get current => _x;

  @override
  bool moveNext() {
    return _count++ < 10;
  }
}

/**
 * Extending the list with ListBase
 */
class MyList<X> extends ListBase<X> {
  X _x;

  MyList(this._x);

  @override
  int get length => 10;

  set length(int l) {}


  X operator [](int index) {
    return _x;
  }

  operator []=(int index, X value) {}
}

/**
 * Extending the list with the mixin
 */

class MyList2<X> extends ListMixin<X> implements List<X> {
  @override
  int get length => this._list.length;

  set length(int l) => this._list.length = l;

  List<X> _list;

  MyList2(this._list):super();


  X operator [](int index) => _list[index];

  operator []=(int index, X value) {
    _list[index] = value;
  }
}

/** This things should work */

// Iterate in the usual way
String test1() {
  MyIterable<String> it = new MyIterable("Valentino");
  String res = "";
  for (String x in it) {
    res = "${res},${x}";
  }
  return res;
}

String test2() {
  return new MyIterable<String>("Mario").join(',');
}

String test3() {
  return new MyList("Giovanni").join(',');
}

String test4() {
  Iterable<String> it = new MyList<String>("Giacomo");
  String res = "";
  for (String x in it) {
    res = "${res},${x}";
  }
  return res;
}

String test5() {
  Iterator<String> i = new MyList<String>("Luigi").iterator;
  String res = "";
  while (i.moveNext()) {
    res = "${res},${i.current}";
  }
  return res;
}

String test6() {
  return new MyList2(new MyList("Leonardo")).join(',');
}

String test7() {
  Iterable<String> it = new MyList2<String>(new MyList("Alfredo"));
  String res = "";
  for (String x in it) {
    res = "${res},${x}";
  }
  return res;
}

String test8() {
  Iterator<String> i = new MyList2<String>(new MyList("Alberto")).iterator;
  String res = "";
  while (i.moveNext()) {
    res = "${res},${i.current}";
  }
  return res;
}
