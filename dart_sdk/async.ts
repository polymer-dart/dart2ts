export * from "./lib/async";

export interface Future<X> extends Promise<X> {
}

/**
 * A simple completer implementation based on
 * ES6 Promise
 */
export class Completer<X> {
    private _future: Future<X>;
    private _resolve: (x: X) => void;
    private _reject: (error: any) => void;

    get future(): Future<X> {
        return this._future;
    }

    complete(x: X): void {
        this._resolve(x);
    }

    completeError(error: any): void {
        this._reject(error);
    }

    constructor() {
        this._future = new _Future<X>((resolve, reject) => {
            this._resolve = resolve;
            this._reject = reject;
        });
    }
}


/**
 * A Future implementation that extends Promise.
 */
class _Future<X> extends Promise<X> implements Future<X> {
    constructor(executor: (resolve: (x: X) => void
        , reject: (error: any) => void) => void) {
        super(executor);
    }
}

export interface Stream<X> {

}

export interface StreamControllerBroadcastConstructor<X> {
    new (): StreamController<X>;
}

/**
 * An iterator
 */
export class StreamController<X> {
    private _stream: _Stream<X>;

    constructor() {
        this._stream = new _Stream<X>();
    }

    static get broadcast(): StreamControllerBroadcastConstructor<any> {
        let ctor = function (): void {

        };
        ctor.prototype = StreamController.prototype;
        return <any>ctor;
    }

    add(x: X): void {
        this._stream.add(x);
    }


}

export interface StreamSubscription<X> {
    cancel():void;
}


class _Stream<X> implements Stream<X> {

    private _closed: boolean = false;

    /**
     *  Implementing the iterable protocols allows
     * to easily implement "await for" constructs.
     */
    get [Symbol.iterator]() {
        return async function* () {
            while(!this._closed) {
                let next: Promise<X> = new Promise((resolve, reject) => {
                    let sub = this.listen((x) => {
                        sub.cancel();
                        resolve(x);
                    });
                });

                yield next;
            }
        }
    }

    private _listeners: Array<(X) => any> = [];

    add(x: X): void {
        this._listeners.forEach((l) => {
            try {
                l(x);
            } catch (e) {
                console.error(e);
            }
        });
    }

    listen(handler: (X) => any):StreamSubscription<X> {
        this._listeners.push(handler);
        return <StreamSubscription<X>>{
          cancel: () => this._listeners.splice(this._listeners.indexOf(handler),1)
        };
    }
}
