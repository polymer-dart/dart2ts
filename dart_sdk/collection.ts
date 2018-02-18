import {Duration} from "./lib/core.js";
import {extendPrototype} from "./utils.js";
import {DartMetadata, IDartMetadata, OverrideMethod, OverrideProperty} from "./decorations.js";


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

    interface ArrayConstructor {
        $from<T>(source: Iterable<T>): Array<T>;
    }

}


export interface DartIterable<T> extends Iterable<T> {
    readonly $first: T;
    readonly $last: T;

    $join(separator: string): string;

    $map<X>(f: (t: T) => X): DartIterable<X>;

    forEach(f: (x: T) => any): void;
}

@DartMetadata({library: 'dart:core'})
export class DartList<T> extends Array<T> implements DartIterable<T> {
    @OverrideMethod('$join', 'join')
    $join(separator: string): string {
        return this.join(separator);
    }

    @OverrideProperty('$first', 'first')
    get $first(): T {
        return this[0];
    }

    @OverrideProperty('$last', 'last')
    get $last(): T {
        return this[this.length - 1];
    }

    @OverrideMethod('$sublist', 'sublist')
    $sublist(from: number, to: number): Array<T> {
        return this.slice(from, to);
    }

    @OverrideMethod('$add', 'add')
    $add(e: T): void {
        this.push(e);
    }

    @OverrideMethod('$remove', 'remove')
    $remove(e: T): void {
        let idx = this.indexOf(e);
        if (idx >= 0) {
            this.splice(this.indexOf(e), 1);
        }
    }

    @OverrideMethod('$map', 'map')
    $map<X>(f: (t: T) => X): DartIterable<X> {
        let self = this;
        return toDartIterable<X>({
            [Symbol.iterator]: function* () {
                for (let t of self) {
                    yield f(t);
                }
            }
        });
    }
}

export function iter<X>(generator: () => Iterator<X>) {
    return toDartIterable({
        [Symbol.iterator]: generator
    });
}

function toDartIterable<X>(x: Iterable<X>): DartIterable<X> {
    @DartMetadata({library: 'dart:core'})
    class _ implements DartIterable<X> {
        @OverrideMethod('$map', 'map')
        $map<T>(f: (t: X) => T): DartIterable<T> {
            let self = this;

            return toDartIterable<T>({
                [Symbol.iterator]: function* () {
                    for (let t of self) {
                        yield f(t);
                    }
                }
            });
        }

        forEach(f: (x: X) => any): void {
            for (let _ of this) {
                f(_);
            }
        }

        @OverrideMethod('$join', 'join')
        $join(separator: string): string {
            return Array.from(this).join(separator);
        }

        @OverrideProperty('$first', 'first')
        get $first(): X {
            let first: X;
            for (let x of this) {
                first = x;
                break;
            }
            return first;
        }

        @OverrideProperty('$last', 'last')
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
    };

    return new _();
}

export class DartMap<K, V>

    extends Map<K, V> {

}


let inited: boolean = false;


export function

initCollections() {
    if (inited) {
        return;
    }

    inited = true;

    extendPrototype(Array, DartList);
    extendPrototype(Map, DartMap);

    Object.defineProperty(Array, "$from", {
        get() {
            return function <X>(source: Iterable<X>): Array<X> {
                return Array.from(source);
            }
        }
    });

}
