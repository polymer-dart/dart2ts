import {Duration} from "./lib/core";

function extendPrototype(type, other) {
    let object = other.prototype;
    Object.getOwnPropertyNames(object).forEach(function (n: string) {
        if (n === 'constructor') {
            return;
        }
        let des: PropertyDescriptor = Object.getOwnPropertyDescriptor(object, n);
        Object.defineProperty(type.prototype, n, des);
    });
    Object.getOwnPropertySymbols(object).forEach(function (n: symbol) {
        let des: PropertyDescriptor = Object.getOwnPropertyDescriptor(object, n);
        Object.defineProperty(type.prototype, n, des);
    });
}


export namespace Symbols {
}

declare global {

    interface Array<T> {
        readonly $first: T;
        readonly $last: T;

        $sublist(from: number, to: number): Array<T>;

        $isEmpty: boolean;
        $isNotEmpty: boolean;

        $add(e: T): void;

        $remove(e: T): void;

        $map<X>(f: (t: T) => X): DartIterable<X>;
    }


    interface PromiseConstructor {
        delayed<T>(d: Duration): Promise<T>;
    }
}


export interface DartIterable<T> extends Iterable<T> {
    readonly $first: T;
    readonly $last: T;

    $join(separator: string): string;

    $map<X>(f: (t: T) => X): DartIterable<X>;
}

export interface DartList<T> extends DartIterable<T> {

}

function toDartIterable<X>(x: Iterable<X>): DartIterable<X> {
    return new (class implements DartIterable<X> {
        $map<T>(f: (t: X) => T): DartIterable<T> {
            return toDartIterable<T>(function* () {
                for (let t of this) {
                    yield f(t);
                }
            }());
        }

        $join(separator: string): string {
            return Array.from(this).join(separator);
        }

        get $first(): X {
            let first: X;
            for (let x of this) {
                first = x;
                break;
            }
            return first;
        }

        get $last(): X {
            let last: X;
            for (let x of this) {
                last = x;
            }
            return last;
        }

        [Symbol.iterator](): Iterator<X> {
            return x[Symbol.iterator]();
        }
    }) as DartIterable<X>;
}


let inited: boolean = false;


interface DartStream<T> extends AsyncIterable<T> {
    $map<U>(mapper: (t: T) => U): DartStream<U>;
}

function toStream<X>(source: AsyncIterable<X>): DartStream<X> {

    return new (class implements DartStream<X> {

        [Symbol.asyncIterator](): AsyncIterator<X> {
            return source[Symbol.asyncIterator]();
        }

        $map<U>(mapper: (t: X) => U): DartStream<U> {
            let it: AsyncIterable<X> = this;
            return toStream((async function* () {
                for await (let x of it) {
                    yield mapper(x);
                }
            })());
        }
    });
}

interface DartFuture<T> extends Promise<T> {
    readonly stream$: DartStream<T>;
}

export function initCollections() {
    if (inited) {
        return;
    }

    extendPrototype(Array, class<T> extends Array<T> implements DartList<T> {
        $join(separator: string): string {
            return this.join(separator);
        }

        get $first(): T {
            return this[0];
        }

        get $last(): T {
            return this[this.length - 1];
        }

        $sublist(from: number, to: number): Array<T> {
            return this.slice(from, to);
        }

        $add(e: T): void {
            this.push(e);
        }

        $remove(e: T): void {
            this.splice(this.indexOf(e), 1);
        }

        $map<X>(f: (t: T) => X): DartIterable<X> {
            let self = this;
            return toDartIterable<X>(function* () {
                for (let t of self) {
                    yield f(t);
                }
            }());
        }
    });

    extendPrototype(Promise, class<X> extends Promise<X> implements DartFuture<X> {
        get stream$(): DartStream<X> {
            let p = this;
            return toStream((async function* () {
                let res: X = await p;
                yield res;
            })());
        }
    });

    Object.defineProperty(Promise, 'delayed', {
        "get": function () {
            return function (d: Duration): Promise<any> {
                return new Promise<any>((resolve, reject) => {
                    setTimeout(() => {
                        resolve();
                    }, d.milliseconds + d.seconds * 1000);
                });
            }
        }
    });

}