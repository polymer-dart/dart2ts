import {Duration} from "./lib/core.js";
import {extend} from "./utils.js";
import {DartMetadata, IDartMetadata, OverrideMethod, OverrideProperty, dartMixin, ConstructorOf, dartMixins} from "./decorations.js";
import * as bare from "./dist/bare";


export namespace Symbols {
}


/**
 * Extend global Array because we want to be able to pass
 * array to dart function and make them work as a Dart List.
 */

declare global {

    interface Array<T> extends DartList<T> {


    }

    interface ArrayConstructor extends DartListConstructor {

    }

}


export interface DartList<X> extends DartIterable<X> {

    readonly $isEmpty: boolean;
    readonly $isNotEmpty: boolean;

    $add(e: X): void;

    $remove(e: X): void;

    readonly $iterator: DartIterator<X>;

    $sublist(from: number, to: number): DartList<X>;

    length: number;

    OPERATOR_INDEX(index: number): X;

    OPERATOR_INDEX_EQ(index: number, value: X): void;

    indexOf(e:X):number;

}

export interface DartListConstructor {
    $from<T>(source: Iterable<T>): DartList<T>;

    generate<T>(count: number, generator: (n: number) => T): DartList<T>;
}

export abstract class DartIterable<T> implements Iterable<T> {


    constructor(...args: Array<any>) {
    }

    [Symbol.iterator](): Iterator<T> {
        return new DartIteratorIteratorWrapper(this.$iterator);
    }

    @OverrideMethod('$map', 'map')
    $map<U>(f: (t: T) => U): DartIterable<U> {
        let self = this;

        return toDartIterable<U>({
            [Symbol.iterator]: function* () {
                for (let t of self) {
                    yield f(t);
                }
            }
        });
    }

    forEach(f: (x: T) => any): void {
        for (let _ of this) {
            f(_);
        }
    }

    @OverrideMethod('$join', 'join')
    $join(separator: string): string {
        return Array.from(this).join(separator);
    }

    @OverrideProperty('$first', 'first')
    get $first(): T {
        let first: T;
        for (let x of this) {
            first = x;
            break;
        }
        return first;
    }

    @OverrideProperty('$last', 'last')
    get $last(): T {
        let last: T;
        for (let x of this) {
            last = x;
        }
        return last;
    }

    $toList(arg?: { growable?: boolean }): Array<T> {
        return Array.from(this);
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


/**
 * A native implementation of DartList, levereging the
 * Array native datatype. It's not exported as it will be mixed in into global array.
 */


@DartMetadata({library: 'dart:core'})
class $DartList<T> extends Array<T> implements DartList<T> {

    static $from<T>(source: DartIterable<T>): DartList<T> {
        return Array.from(source);
    }

    static generate<T>(count: number, generator: (n: number) => T): Array<T> {
        return Array.from((function* () {
            for (let i = 0; i < count; i++) {
                yield generator(i);
            }
        })());
    }


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

    $toList(arg?: { growable?: boolean }): Array<T> {
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

    OPERATOR_INDEX(index: number): T {
        return this[index];
    }

    OPERATOR_INDEX_EQ(index: number, value: T): void {
        this[index] = value;
    }
}

/**
 * A list base should implement the DartList cont
 */
export interface ListBase<X> extends DartList<X> {

}

export interface ListBaseConstructor extends DartListConstructor {
    new<X>(...args: Array<any>): ListBase<X>;

    new<X>(n?: number): ListBase<X>;
}

@DartMetadata({library: 'dart:core'})
export abstract class $ListBase<X> implements DartList<X> {
    $isEmpty: boolean;
    $isNotEmpty: boolean;
    $iterator: DartIterator<X>;
    abstract length: number;

    $add(e: X): void {
        this.OPERATOR_INDEX_EQ(this.length,e);
    }

    $remove(e: X): void {
        this.indexOf(e);
    }

    $sublist(from: number, to: number): DartList<X> {
        return undefined;
    }

    abstract OPERATOR_INDEX(index: number): X ;

    abstract OPERATOR_INDEX_EQ(index: number, value: X): void ;


    [Symbol.iterator](): Iterator<X> {
        return undefined;
    }

    $map<U>(f: (t: X) => U): DartIterable<U> {
        return undefined;
    }

    forEach(f: (x: X) => any): void {
    }

    $join(separator: string): string {
        return undefined;
    }

    $first(): X {
        return undefined;
    }

    $last(): X {
        return undefined;
    }

    $toList(arg?: { growable?: boolean }): Array<X> {
        return undefined;
    }

    $firstWhere(cond: (x: X) => boolean, opts?: { orElse?: () => X }): X {
        return undefined;
    }

    $where(cond: (t: X) => boolean): DartIterable<X> {
        return undefined;
    }
    constructor(...args: Array<any>)
    constructor(n?: number) {
        super(!isNaN(n) ? n : 0);
    }
}

export const ListBase: ListBaseConstructor = $ListBase as ListBaseConstructor;

export interface Pippo {
    x: string;
}

export interface PippoConstructor extends ConstructorOf<Pippo> {

}

export class $Pippo {
    x: string;
}

export const Pippo: PippoConstructor = $Pippo;

export interface Ciccio {
    w: string;
}

export interface CiccioConstructor extends ConstructorOf<Ciccio> {

}

export class $Ciccio {
    w: string;
}

export const Ciccio: CiccioConstructor = $Ciccio;


/**
 * How to define a class and a constructor preserving generics and mixin.
 * Another advantage of this approach is that thirdy party can extend constructors (you got an interface to extend).
 */


// 0. Define a type for the mixins (if any)

export type MyListMixins<X> = Pippo & Ciccio;

// 1. Define an interface extending the base class and the mixins (if any) and interfaces (if any), gathering type arguments and adding props
export interface MyList<X> extends ListBase<X>, MyListMixins<X> {
    constructor: MyListConstructor;
    // new props and methods
    y: string;
}

// 2. Define an interface for the constructor with all statics, type arguments will go in the "new" declarations
export interface MyListConstructor extends ListBaseConstructor {
    // statics :
    X: string;

    // constructors :
    new<X>(...args): MyList<X>;
}

// 3: Declare a cons whose type is the constructor with the implementation. Mixins will be implemented with the dartMixin function with the bsase class as first, the rest is left as usual
export const MyList: MyListConstructor = class extends dartMixin(dartMixin(ListBase, Pippo), Ciccio) {
    $iterator: DartIterator<any>;
    static X: string = "XXX";
    y: string;

    constructor(...args) {
        super(...args);
    }
};


// You can instantiate with the type argument
let l: MyList<number> = new MyList<number>();
let l2 = new l.constructor<string>();
l2[10] = "ciao";

l.x = "ciao";
l.y = "ugo";
l.w = "ciccio";
console.log(`len : ${l.length}, static : ${MyList.X}`);
// Type checking is preserved (you'r not alloed assign a string for example)
l[10] = 15;


let n: ListBase<number> = l;
n[10] = 15;

// Strategy #2 :

class MyList2<X> extends dartMixin(ListBase, Pippo) implements ListBase<X>, Pippo {

}

// Doesn't preserve type checking (you can assign a string)
let ll: MyList2<number> = new MyList2(1);
ll[22] = "ciao";

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

    extend(Array, $DartList);
    extend(Map, DartMap);


}
