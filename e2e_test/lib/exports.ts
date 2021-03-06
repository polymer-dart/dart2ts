import * as s1 from './sample1';
import * as t1 from './test_cascading';
import * as t2 from './test_js_anno';
import * as t3 from './test_anno';
import * as test_map$ from './test_map';
import * as test_strange from './test_strange';
import * as test_async_closure from './test_async_closure';
import * as try_catch from './try_catch';
import * as test_unicode from './test_unicodeEscape';
import * as test_init from './test_initializers';

export default {
    testAsync: s1.testAsync,
    testCascading: t1.testCascading,
    test_js_anno: t2,
    testMetadata: t3.testMetadata,
    propAnno: t3.propAnno,
    test_map: test_map$,
    test_strange: test_strange,
    test_async_closure: test_async_closure,
    try_catch: try_catch,
    test_unicode: test_unicode,
    test_init : test_init
}
