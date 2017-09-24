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

export namespace ListHelpers {
    export namespace first {
        export function get<T>(list: Array<T>): T {
            return list[0];
        }
    }

    export namespace methods {
        export function add<T>(list:Array<T>,elem:T):void {
            list.push(elem);
        }

        export function remove<T>(list:Array<T>,elem:T):void {
            list.splice(list.indexOf(elem),1);
        }

        export function from(x:any):Array<any> {
            return Array.prototype.slice.call(x);
        }
    }
}



