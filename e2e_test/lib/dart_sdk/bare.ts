// Some triks borrowed from dart_sdk


function named(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    descriptor.get = () => namedConstructor(target, propertyKey);
}


function namedConstructor(clazz, name) {
    let proto = clazz.prototype;
    let initMethod = proto[name];
    let ctor = function (...args) {
        initMethod.apply(this, args);
    };
    ctor.prototype = proto;
    return <any>ctor;
}

let init: symbol = Symbol();

class DartObject {

    constructor(...args) {
        this[init] && this[init].apply(this, args);
    }

    static named(name:String) {
        return namedConstructor(this,name);
    }
}

export {named, namedConstructor, init, DartObject as Object};