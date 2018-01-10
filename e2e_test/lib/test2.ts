import * as lib1 from "./test";


var x:lib1.SampleClass = new lib1.SampleClass();
console.log(`${x.doc===lib1.module.document} is true`);
