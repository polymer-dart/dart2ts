# STRATEGY

Different use cases to take into account for designing the translation strategy

 1. Language constructs :
   - Future / Promise
   - Iterable / Iterator protocol
   - async / async
   - sync / function*
   - async* / async function*
   
## translating extension methods

Calling a dart extension method or property on an unknown object cannot be mapped to an extension method reliably.

The default translation for calling a method or property is to exactly call it
 -  DART: 
     ```dart
    var x = getSomeX() as dynamic;
    print("${x.first}");  // If x is a list it should call extension property first 
    ```  
 - TS (default):
    ```typescript
    let x = getSomeX();
    core.print(`${x.first}`);
    ```
For this reason we should not use extension methods but instead define `DartArray` that "extends" `Array` and provides the new methods or properties we need.

How should we treat the following cases:
 1. Dart code that calls a TS library and passes a `DartArray` when it expects an `Array`
 2. Dart code that calls a TS library that returns an `Array` when dart wants a `DartArray`
 3. TS code that calls a Dart library and passes a `Array` when dart wants a `DartArray`
 4. TS code that calls a Dart library that returns a `DartArray` instead of an  `Array`
 
We have to support thirdy party library that works with `dartdevc` so we cannot restrict by forcing the use of a different class than `List`  or leverage the analyzer.
For example this code shoud work

```dart
myMethod() {
  return new List() as dynamic;
}

myMethod().add("hi");

```

This will be translated as
```typescript
function myMethod() {
    return (any) new Array();
}

myMethod().add("hi");
```

But Ts `Array` doesn't have and `add` method! How does `dartdevc` handle this ? It will translate it with `dsend` that will check dynamically for extension method
otherwise it will call it directly if analyzer could detect it : 
```javascript

dart.dsend(test.myMethod(), 'add', "hi");   // if myMethod is declared as returning `dynamic`
test.myMethod()[dartx.add]("hi");   // if myMethod is defined as returning  `List`
```

`dart.dsend` will check if 'add` corresponds to an extension method ([dartx.add] in this case) and if the actual target has it and then calls it, otherwise it will call `add`.

Estension method are added to the `Array` prototype thus javascript libraries calling dart will always pass object with extension method enabled.

There's also an `registerExtension` method that will add the extension to the original prototype.

 
What about using decorators ?



        