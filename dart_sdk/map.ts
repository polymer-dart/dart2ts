export class DartMap<K, V> {
    private _map: Map<K, V> = new Map();

    constructor(entries?: Iterable<[K, V]>) {
        this._map = new Map(entries || []);
    }

    get(k: K): V {
        return this._map.get(k);
    }

    set(k: K, v: V): void {
        this._map.set(k, v);
    }
}