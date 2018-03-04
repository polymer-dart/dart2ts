testMap() {
  Map<String, int> simpleMap = new Map();
  simpleMap['ciao'] = 1;

  Map<String, Map<String, int>> m = {
    "one": {
      "alpha": 1,
      "beta": 2,
    },
    "two": {
      "gamma": 3,
      "delta": 4,
    }
  };

  return m['two']['gamma'];
}
