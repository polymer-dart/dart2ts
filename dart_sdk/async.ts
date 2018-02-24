// export * from "./lib/async";

import * as core from './core.js';
import {Duration} from "./lib/core.js";
import {extendPrototype} from "./utils.js";


declare global {
    interface PromiseConstructor {
        delayed<T>(d: Duration, val?: () => T): Promise<T>;

        wait(promises: Iterable<Promise<any>>): Promise<Array<any>>;
    }
}


export interface DartStream<T> extends AsyncIterable<T> {
    $map<U>(mapper: (t: T) => U): DartStream<U>;
}

export function toStream<X>(source: AsyncIterable<X>): DartStream<X> {

    return new (class implements DartStream<X> {

        [Symbol.asyncIterator](): AsyncIterator<X> {
            return source[Symbol.asyncIterator]();
        }

        $map<U>(mapper: (t: X) => U): DartStream<U> {
            let it: AsyncIterable<X> = this;
            return toStream({
                [Symbol.asyncIterator]: async function* () {
                    for await (let x of it) {
                        yield mapper(x);
                    }
                }
            });
        }
    });
}

export function stream<X>(generator: () => AsyncIterator<X>): DartStream<X> {
    return toStream({
        [Symbol.asyncIterator]: generator
    });
}

class DartFuture<T> extends Promise<T> {
    get stream$(): DartStream<T> {
        let p = this;
        return toStream({
            [Symbol.asyncIterator]: async function* () {
                let res: T = await p;
                yield res;
            }
        });
    }
}


let inited: boolean = false;


export function initAsync() {
    if (inited) {
        return;
    }

    inited = true;


    extendPrototype(Promise, DartFuture);

    Object.defineProperty(Promise, 'delayed', {
        "get": function () {
            return function <T>(d: Duration, val?: () => T): Promise<T> {
                return new Promise<any>((resolve, reject) => {
                    setTimeout(() => {
                        resolve(val && val());
                    }, d.inMilliseconds);
                });
            }
        }
    });

    Object.defineProperty(Promise, 'wait', {
        "get": function () {
            return async function (promises: Iterable<Promise<any>>): Promise<Array<any>> {
                return await Promise.all(Array.from(promises));
            }
        }
    });

}


/**
 * A simple completer implementation based on
 * ES6 Promise
 */
export class Completer<X> {
    private _future: Promise<X>;
    private _resolve: (x: X) => void;
    private _reject: (error: any) => void;

    isCompleted: boolean = false;

    static $create<X>(): Completer<X> {
        return new Completer();
    }

    get future(): Promise<X> {
        return this._future;
    }

    complete(x?: X): void {
        this.isCompleted = true;
        this._resolve(x);
    }

    completeError(error: any): void {
        this._reject(error);
    }

    constructor() {
        this._future = new Promise<X>((resolve, reject) => {
            this._resolve = resolve;
            this._reject = reject;
        });
    }
}


/**
 * An iterator
 */
export class StreamController<X> {
    private _stream: _Stream<X>;

    get stream(): DartStream<X> {
        return this._stream;
    }

    constructor(arg?: { onListen?: () => any, onCancel?: () => any, sync?: boolean }) {
        this._stream = new _Stream<X>(arg);
    }

    // Factory constructor
    static broadcast<Y>(arg?: { onListen?: () => any, onCancel?: () => any, sync?: boolean }): StreamController<Y> {
        return new StreamController<Y>(arg);
    }

    add(x: X): void {
        this._stream.add(x);
    }

    close(): void {
        this._stream.close();
    }

}

export interface StreamSink<X> {
    add(event: X): void;

    close(): void;

}

export interface StreamSubscription<X> {
    cancel(): void;
}


function noop<X>() {
}

class _Stream<X> implements DartStream<X> {
    private _onListen: () => any;
    private _onCancel: () => any;

    constructor(arg?: { onListen?: () => any, onCancel?: () => any, sync?: boolean }) {
        if (arg) {
            this._onListen = arg.onListen;
            this._onCancel = arg.onCancel;
        }

        this._onListen = this._onListen || noop;
        this._onCancel = this._onCancel || noop;
    }

    $map<U>(mapper: (t: X) => U): DartStream<U> {
        return toStream(this).$map(mapper);
    }

    private _closed: boolean = false;

    private _broadcast: Array<Broadcast<X>> = [];

    /**
     *  Implementing the iterable protocols allows
     * to easily implement "await for" constructs.
     */
    [Symbol.asyncIterator]() {
        let b: Broadcast<X> = new Broadcast<X>(() => {
            this._broadcast.$remove(b);
            this._removeListener(b.listener);
        });
        this._broadcast.push(b);
        this._addListener(b.listener);
        return b.start();
    }

    private _listeners: Array<(X) => any> = [];

    private _addListener(listener: (X) => any) {
        this._listeners.push(listener);
        if (this._listeners.length == 1) {
            this._onListen();
        }
    }

    private _removeListener(listener: (x: X) => any) {
        this._listeners.$remove(listener);
        if (this._listeners.$isEmpty) {
            this._onCancel();
        }
    }

    add(x: X): void {
        this._listeners.forEach((l) => {
            try {
                l(x);
            } catch (e) {
                console.error(e);
            }
        });
    }

    close(): void {
        if (this._closed) {
            return;
        }
        this._closed = true;
        this._broadcast.slice().forEach((b) => b.close());
    }

    listen(handler: (X) => any): StreamSubscription<X> {
        this._addListener(handler);
        return <StreamSubscription<X>>{
            cancel: () => this._listeners.$remove(handler)
        };
    }
}

interface EternalPromise<X> {
    current: X;
    next: Promise<EternalPromise<X>>;
}


const BroadCastClosed = Symbol("BroadcastClosed");

/**
 * NOTE : using complete instead of completeError to terminate the
 * consumer to avoid annoying exception when completing a promise that's not in await state.
 */
class Broadcast<X> {
    listener: (x: X) => void = (x: X) => this.add(x);

    private _currentConsumer: Completer<EternalPromise<X>>;
    private _currentProvider: Promise<EternalPromise<X>>;
    private _onclose: () => void;
    private _closed: boolean = false;

    close(): void {
        this._closed = true;

        this._currentConsumer.complete(BroadCastClosed as any);

    }

    constructor(onClose: () => void) {
        this._onclose = onClose;
        this._currentConsumer = new Completer<EternalPromise<X>>();
        this._currentProvider = this._currentConsumer.future;
    }

    async * start(): AsyncIterator<X> {
        do {
            try {
                let p = await this._currentProvider;
                if ((p as any) !== BroadCastClosed) {
                    yield p.current;
                    this._currentProvider = p.next;
                }
            } catch (e) {
                console.warn(`Finished stream, isClose:${this._closed}`);
                if (e !== BroadCastClosed) {
                    throw e;
                }
            }
        } while (!this._closed);

        this._onclose();
    }


    add(x: X): void {
        if (this._closed) {
            throw "Cannot add to a closed listener";
        }

        let old = this._currentConsumer;
        this._currentConsumer = new Completer<EternalPromise<X>>();

        old.complete({
            current: x,
            next: this._currentConsumer.future
        });

    }

}