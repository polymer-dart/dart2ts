// Some triks borrowed from dart_sdk

// Extend global Array
import * as collection from './collection';
import {initCollections as initAsync} from "./async";
import {initNatives} from "./natives";


collection.initCollections();
initAsync();
initNatives();

export function invokeMethod(o: any, method: string, ...args: Array<any>): any {
    o = o || this;
    return o[method].apply(o, args);
}


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

    export namespace last {
        export function get<T>(list: Array<T>): T {
            return list[list.length - 1];
        }
    }

    export namespace isEmpty {
        export function get<X>(list: Array<X>): boolean {
            return list.length == 0;
        }
    }

    export namespace isNotEmpty {
        export function get<X>(list: Array<X>): boolean {
            return list.length > 0;
        }
    }

    export namespace methods {
        export function add<T>(list: Array<T>, elem: T): void {
            list.push(elem);
        }

        export function remove<T>(list: Array<T>, elem: T): void {
            list.splice(list.indexOf(elem), 1);
        }

        export function from<X>(x: Iterable<X>): Array<X> {
            return Array.from(x);
        }

        export function filled<X>(len: number, what: X): Array<X> {
            return Array.from(IterableHelpers.methods.filled(len, what));
        }

        export function removeLast<X>(list: Array<X>): Array<X> {
            return list.slice(0, -1);
        }

        export function generate<X>(count: number, generator: (number) => X, args?: { growable?: boolean }): Array<X> {
            return Array.from(IterableHelpers.methods.generate(count, generator, args));
        }
    }
}

class StateError extends Error {

}

export namespace IterableHelpers {

    export namespace last {

        export function get<X>(it: Iterable<X>): X {
            let last: X;
            let empty: boolean = true;
            for (let elem of it) {
                last = elem;
                empty = false;
            }

            if (empty) {
                throw new StateError();
            }

            return last;
        }

    }

    export namespace methods {
        export function where<X>(it: Iterable<X>, filter: (X) => boolean): Iterable<X> {
            return {
                [Symbol.iterator]: function* () {
                    for (let x of it) {
                        if (filter(x)) {
                            yield x;
                        }
                    }
                }
            }
        }


        export function lastWhere<X>(it: Iterable<X>, where: (X) => boolean, args?: { orElse?: () => X }) {
            try {
                return IterableHelpers.last.get(IterableHelpers.methods.where(it, where));
            } catch (error) {
                if (error instanceof StateError && args.orElse) {
                    return args.orElse();
                }

                throw error;
            }
        }

        export function generate<X>(count: number, generator: (number) => X, args?: { growable?: boolean }): Iterable<X> {
            let {growable} = Object.assign({growable: false}, args);
            return {
                [Symbol.iterator]: function* () {
                    for (let i: number = 0; i < count; i++) {
                        yield generator(i);
                    }
                }
            }
        }

        export function map<X, Y>(it: Iterable<X>, mapper: (X) => Y): Iterable<Y> {
            return {
                [Symbol.iterator]: function* () {
                    for (let x of it) {
                        yield mapper(x);
                    }
                }
            }
        }

        export function join<X>(it: Iterable<X>, sep?: string): string {
            return Array.from(it).join(sep);
        }

        export function take<X>(it: Iterable<X>, num: number): Iterable<X> {
            return {
                [Symbol.iterator]: function* () {
                    let ii: Iterator<X> = it[Symbol.iterator]();
                    let res = ii.next();
                    while (num-- > 0 && !res.done) {
                        yield res.value;
                        res = ii.next();
                    }
                }
            }
        }

        export function filled<X>(len: number, what: X): Iterable<X> {
            return {
                [Symbol.iterator]: function* () {
                    while (len-- > 0) {
                        yield what;
                    }
                }
            }
        }
    }
}

export namespace NumberHelpers {
    export namespace methods {
        export function parse(s: string): number {
            return parseFloat(s);
        }
    }
}

export namespace IntHelpers {
    export namespace methods {
        export function parse(s: string): number {
            return parseInt(s);
        }
    }
}

export namespace StringHelpers {
    export namespace codeUnits {
        export function get(x: String): Iterable<number> {
            return {
                [Symbol.iterator]: function* () {
                    for (let c of x) {
                        yield c.charCodeAt(0);
                    }
                }
            }
        }
    }

    export namespace isNotEmpty {
        export function get(x: string): boolean {
            return x.length > 0;
        }
    }

    export namespace isEmpty {
        export function get(x: string): boolean {
            return x.length == 0;
        }
    }


    export namespace methods {
        export function allMatches(pattern: string, tgt: string): Array<string> {
            let p = undefined;
            return Array.from((function* () {
                while ((p = tgt.indexOf(pattern, p) >= 0)) {
                    p += tgt.length;
                    yield pattern;
                }
            })());
        }


        export function codeUnitAt(s: string, p: number): number {
            return s.charCodeAt(p);
        }

        export function replaceAll(s: string, what: string | RegExp, which: string): string {
            return s.replace(what, which);
        }

        export function contains(s: string, what: string): boolean {
            return s.indexOf(what) >= 0;
        }
    }
}

export function callGenericMethod(target: any, methodName: string, ...args: Array<any>): any {
    // Here we should intercept string and list methods

    // If not intercepts :
    return target[methodName].call(target, ...args);
}

export function is(object: any, type: any): boolean {
    if (typeof type === 'string') {
        return typeof object === type;
    }
    return object instanceof type;
}

export function isNot(object: any, type: any): boolean {
    return !is(object, type);
}

export function readProperty(obj: any, prop: string) {
    return obj[prop];
}

export function writeProperty(obj: any, prop: string, val: any) {
    obj[prop] = val;
}


export function invokeBinaryOperand<T>(op: string, left: T, right: any): T {
    return {
        '+': (a, b) => a + b,
        '~/': (a, b) => Math.trunc(a / b)
    }[op](left, right);
}