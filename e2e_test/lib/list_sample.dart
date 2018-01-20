import 'function_declaration.dart';

bool doSomethingWithLists() {
  List<String> list = [
    "one",
    "two",
    "three",
    "four",
  ];


  var e = list.map((s)=> "Value ${s}");

  List<String> anotherList = e.toList();

  print("First ${anotherList.first} , ${anotherList.last} : ${anotherList.sublist(2,3).first}");

  var x;

  x = anotherList;

  print("First ${x.first} , ${x.last} : ${x.sublist(2,3).first}");


  return true;
}



void useTopFromAnother() {
  topLevelSetter=doSomethingWithLists;

  topLevelVar = doSomethingWithLists;

  topLevelVar();

  topLevelSetter();

  print("F1 :${topLevelSetter}, F2: ${topLevelVar}");
}