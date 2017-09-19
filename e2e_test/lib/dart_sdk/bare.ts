// Some triks borrowed from dart_sdk

function defineNamedConstructor(clazz, name) {
    let proto = clazz.prototype;
    let initMethod = proto[name];
    let ctor = function (...args) {
        initMethod.apply(this, args);
    };
    ctor.prototype = proto;
    Object.defineProperty(clazz, name, {value: ctor, configurable: true});
};


let init:symbol = Symbol();

class DartObject {

    constructor(...args) {
        this[init]&&this[init].apply(this,args);
    }
}

export {defineNamedConstructor,init,DartObject as Object};