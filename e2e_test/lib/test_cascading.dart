class MyClaz {
  String value;
  MyClaz another;
  Function func;
  Function func2;

  void setValue(String v) {
    value = v;
  }
}

class Another {
  String funcAnother() {
    return "Hi";
  }
}

testCascading() {
  Another another = new Another();
  return new MyClaz()
    ..setValue('ciao')
    ..another = (new MyClaz()..value = "Ugo")
    ..func = ((String x) {
      String y = "${x}!";
      return y;
    })
    ..func2 = (() {
      return another.funcAnother();
    });
}
