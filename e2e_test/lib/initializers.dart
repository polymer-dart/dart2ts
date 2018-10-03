class WithInit {
  static const String CONST="ciao";
  String field1= "ciao";
  int field2 = 2;

  WithInit();

  WithInit.named(this.field2,{this.field1}) {

  }
}

