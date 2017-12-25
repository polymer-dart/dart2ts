void doSomethingWithLists() {
  List<String> list = [
    "one",
    "two",
    "three",
    "four",
  ];


  var e = list.map((s)-> "Value ${s}");

  List<String> anotherList = e.toList();

  print("First ${anotherList.first} , ${anotherList.last} : ${anotherList.sublist(2,3).first}");

  var x;

  x = anotherList;

  print("First ${x.first} , ${x.last} : ${x.sublist(2,3).first}");

}
