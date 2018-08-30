/**
 * Exporing a new way for classes and modules
 */

export class _MyClass<X, Y, Z> {
    field1: X;
    static STATIC: number = 10;

    method1(y: Y): Array<Z> {
        return [];
    }

    static get anotherConstructor(): MyClass$anotherConstructor {
        let ctor = function <X, Y, Z>(this: _MyClass<X, Y, Z>, x: X) {
            this.field1 = x;
        };
        ctor.prototype = _MyClass.prototype;
        return ctor as any as MyClass$anotherConstructor;
    }

    constructor() {

    }
}

export interface MyClass$anotherConstructor {
    new<X, Y, Z>(x: X): _MyClass<X, Y, Z>;
}

export interface MyClass$Static {

}

export interface MyClass$Constructor extends MyClass$Static {

    new<X, Y, Z>(): _MyClass<X, Y, Z>;
}

/**
 * Derived class
 */

export class _MyOtherClass<X> extends module.MyClass<X, X, Array<X>> {
    anotherField: X;

    method2(x1: X, x2: X): Array<Array<X>> {
        return super.method1(x1);
    }

    constructor(x: X) {
        super();
        this.field1 = x;
        this.anotherField = x;
    }
}

export interface MyOtherClass$Constructor extends MyClass$Static {
    new<X>(x: X): _MyOtherClass<X>;
}

/**
 * Mofulr
 * @type {{MyClass(): MyClass$Constructor; MyOtherClass(): MyOtherClass$Constructor}}
 */

var module = {
    get MyClass(): MyClass$Constructor {
        return _MyClass;
    },

    get MyOtherClass(): MyOtherClass$Constructor {
        return _MyOtherClass;
    }
};

export default module;