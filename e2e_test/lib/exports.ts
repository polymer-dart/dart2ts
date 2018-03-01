import * as s1 from './sample1.js';
import * as t1 from './test_cascading.js';
import * as t2 from './test_js_anno.js';

// Can I use a ts namespace to to this ?
window["tests"] = {
    testAsync: s1.testAsync,
    testCascading: t1.testCascading,
    t2MyClass: t2.MyClass
};