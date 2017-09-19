// Some triks borrowed from dart_sdk


function named(name : symbol) {
    return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
        descriptor.get = () => namedConstructor(target,name);
    };
}

function namedConstructor(clazz, name) {
    let proto = clazz.prototype;
    let initMethod = proto[name];
    let ctor = function (...args) {
        initMethod.apply(this, args);
    };
    ctor.prototype = proto;
    return ctor
}

let init: symbol = Symbol();

class DartObject {

    constructor(...args) {
        this[init] && this[init].apply(this, args);
    }
}

export {named, namedConstructor, init, DartObject as Object};