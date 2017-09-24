// Some triks borrowed from dart_sdk


export function named(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    descriptor.get = () => namedConstructor(target, propertyKey);
}


export function namedConstructor(clazz, name) {
    let proto = clazz.prototype;
    let initMethod = proto[name];
    let ctor = function (...args) {
        initMethod.apply(this, args);
    };
    ctor.prototype = proto;
    return <any>ctor;
}

export let init: symbol = Symbol();

export namespace List {
    export namespace first {
        export function get<T>(list: Array<T>): T {
            return list[0];
        }
    }


}


export class Expando<T> {
    sym: symbol;

    constructor() {
        this.sym = Symbol();
    }
}

export namespace Expando {
    export namespace index {
        export function get<T>(t: Expando<T>, index) {
            return index[t.sym];
        }

        export function set<T>(t: Expando<T>, index, value) {
            index[t.sym] = value;
        }
    }

}

