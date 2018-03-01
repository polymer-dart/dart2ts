import * as s1 from './sample1.js';
import * as t1 from './test_cascading.js';

// Can I use a ts namespace to to this ?
window["tests"] = {
    testAsync: s1.testAsync,
    testCascading: t1.testCascading
};