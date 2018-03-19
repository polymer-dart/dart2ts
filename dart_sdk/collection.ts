import {Duration} from "./lib/core.js";
import {extendPrototype} from "./utils.js";
import {DartMetadata, IDartMetadata, OverrideMethod, OverrideProperty} from "./decorations.js";


export namespace Symbols {
}

declare global {

    interface Array<T> extends DartIterable<T> {

        $sublist(from: number, to: number): Array<T>;

        readonly $isEmpty: boolean;
        readonly $isNotEmpty: boolean;

        $add(e: T): void;

        $remove(e: T): void;


    }

    interface ArrayConstructor {
        $from<T>(source: Iterable<T>): Array<T>;

        generate<T>(count: number, generator: (n: number) => T): Array<T>;
    }

}


export abstract class DartIterable<T> implements Iterable<T> {
    [Symbol.iterator](): Iterator<T> {
        return new DartIteratorIteratorWrapper(this.$iterator);
    }

    readonly $first: T;
    readonly $last: T;

    abstract $join(separator: string): string;

    abstract $map<X>(f: (t: T) => X): DartIterable<X>;

    abstract forEach(f: (x: T) => any): void;

    abstract $toList(arg?: { growable?: boolean }): DartList<T>;

    abstract $firstWhere(cond: (t: T) => boolean, opts?: { orElse?: () => T }): T;

    abstract $where(cond: (t: T) => boolean): DartIterable<T>;

    abstract readonly $iterator: DartIterator<T>;
}


export class ReturnIterator {
    private _value: any;
    get value() {
        return this._value;
    }

    constructor(value?: any) {
        this._value = value;
    }
}

export abstract class DartIterator<X> {

    abstract moveNext(): boolean;

    abstract readonly current: X;
}

export class DartIteratorIteratorWrapper<X> implements Iterator<X> {
    private _dartIterator: DartIterator<X>;

    constructor(dartIterator: DartIterator<X>) {
        this._dartIterator = dartIterator;
    }

    next(value?: any): IteratorResult<X> {
        return {
            done: !this._dartIterator.moveNext(),
            value: this._dartIterator.current
        };
    }

}

export class IteratorDartIteratorWrapper<X> extends DartIterator<X> {

    private _iterator: Iterator<X>;
    private _current: X;

    constructor(i: Iterator<X>) {
        super();
        this._iterator = i;
    }

    get current(): X {
        return this._current;
    }

    moveNext(): boolean {
        let res: IteratorResult<X> = this._iterator.next();
        this._current = res.value;
        return !res.done;
    }

}


@DartMetadata({library: 'dart:core'})
export class DartList<T> extends Array<T> implements DartIterable<T> {
    get $iterator(): DartIterator<T> {
        return new IteratorDartIteratorWrapper(this[Symbol.iterator]());
    }

    get $isEmpty(): boolean {
        return this.length == 0;
    }

    get $isNotEmpty(): boolean {
        return this.length != 0;
    }


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

    $toList(arg?: { growable?: boolean }): DartList<T> {
        return this;
    }

    $firstWhere(cond: (x: T) => boolean, opts?: { orElse?: () => T }): T {
        for (let x of this) {
            if (cond(x)) {
                return x;
            }
        }
        if (opts !== null && opts.orElse !== null) {
            return opts.orElse();
        }

        throw "not found any and not or Else";
    }

    $where(cond: (t: T) => boolean): DartIterable<T> {
        return iter((function* () {
            for (let t of this) {
                if (cond(t)) {
                    yield t;
                }
            }
        }).bind(this));
    }
}

export function iter<X>(generator: () => Iterator<X>) {
    return toDartIterable({
        [Symbol.iterator]: generator
    });
}

function toDartIterable<X>(x: Iterable<X>): DartIterable<X> {
    @DartMetadata({library: 'dart:core'})
    class _ extends DartIterable<X> {
        get $iterator(): DartIterator<X> {
            return new IteratorDartIteratorWrapper(x[Symbol.iterator]());
        }

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

        $toList(arg?: { growable?: boolean }): DartList<X> {
            return Array.from(this);
        }

        $firstWhere(cond: (x: X) => boolean, opts?: { orElse?: () => X }): X {
            for (let x of this) {
                if (cond(x)) {
                    return x;
                }
            }
            if (opts !== null && opts.orElse !== null) {
                return opts.orElse();
            }

            throw "not found any and not or Else";
        }

        $where(cond: (t: X) => boolean): DartIterable<X> {
            return iter((function* () {
                for (let t of this) {
                    if (cond(t)) {
                        yield t;
                    }
                }
            }).bind(this));
        }
    }

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

    Object.defineProperty(Array, "generate", {
        get() {
            return <T>(count: number, generator: (n: number) => T): Array<T> => Array.from((function* () {
                for (let i = 0; i < count; i++) {
                    yield generator(i);
                }
            })());
        }
    });

}
