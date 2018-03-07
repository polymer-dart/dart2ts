import 'package:js/js.dart';

import 'mini_html.dart';

class MyClass {
  @JS('otherName')
  static String myName = 'hi';
}

abstract class OtherClass extends HTMLElement {
  void testExtAnno() {
    HTMLElement div1 = document.createElement('div');
    HTMLElement div2 = createDiv();

    div1.appendChild(div2);

    window.scroll(10, 20);
  }
}

class AutoRefParent {
  AutoRef x;
  int c = 0;

  void doIt() {
    c++;
  }
}

class AutoRef extends AutoRefParent {
  AutoRef autoRefProp() {
    AutoRef ref = new AutoRef();
    ref.x = x; // reference to x that's also an class method
    ref.x.x = x.x; // move a3 -> a3
    ref.doIt(); // ref.c = 1
    var dynRef = ref as dynamic;
    dynRef.x = this; // reference to x that's also an class method ,
    dynRef.doIt(); // rec.c = 2

    Function mRef = ref.x.doIt;
    Function mRef2 = doIt;
    Function mRef3 = ref.doIt;

    mRef(); // ref.x.c=1
    mRef2(); // ref.x.c=2
    mRef3(); // ref.c = 3

    return ref;
  }
}

AutoRef testRefs() {
  AutoRef a1 = new AutoRef();
  AutoRef a2 = new AutoRef();
  AutoRef a3 = new AutoRef();
  a1.x = a2;
  a2.x = a3;

  return a1.autoRefProp();
}
