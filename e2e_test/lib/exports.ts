import * as s1 from './sample1.js';

// Can I use a ts namespace to to this ?
window["tests"] = {
    testAsync: s1.testAsync
};