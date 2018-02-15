/**
 *  NOT YET SUPPORTED


class MyList<X> extends List<X> {

  Iterable<Y> map<Y>(Y mapper<X,Y>(X x)) {
    return super.map((x) {
      print('mapping ${x}');
      return mapper<X,Y>(x);
    });
  }
}
 */