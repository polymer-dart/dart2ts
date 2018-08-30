import * as lib3 from "./map";
import * as lib1 from "./collection";
import {List} from "./lib/list";

class NativeList<E> extends Array<E> implements List<E> {
    $iterator: lib1.DartIterator<E>;

    add(value: E): void {
        this.push(value);
    }

    addAll(iterable: lib1.DartIterable<E>): void {
        iterable.forEach((x)=>this.add(x));
    }

    asMap(): lib3.DartMap<number, E> {
        return undefined;
    }

    clear(): void {
        this.length=0;
    }

    fillRange(start: number, end: number, fillValue?: E): void {
        for (;start<end;start++) {
            this[start]=fillValue;
        }
    }

    getRange(start: number, end: number): lib1.DartIterable<E> {
        return this.slice(start,end);
    }

    insert(index: number, element: E): void {
        this.splice(index,0,element);
    }

    insertAll(index: number, iterable: lib1.DartIterable<E>): void {
        let vals:Array<E> = Array.from(iterable);
        this.splice(index,0,... vals);
    }

    remove(value: Object): boolean {
        return false;
    }

    removeAt(index: number): E {
        return undefined;
    }

    removeLast(): E {
        return undefined;
    }

    removeRange(start: number, end: number): void {
    }

    removeWhere(test: <E>(element: E) => boolean): void {
    }

    replaceRange(start: number, end: number, replacement: DartIterable<E>): void {
    }

    retainWhere(test: <E>(element: E) => boolean): void {
    }

    get reversed(): DartIterable<E> {
        return undefined;
    }

    setAll(index: number, iterable: DartIterable<E>): void {
    }

    setRange(start: number, end: number, iterable: DartIterable<E>, skipCount?: number): void {
    }

    shuffle(random?: any): void {
    }

    sublist(start: number, end?: number): List<E> {
        return undefined;
    }

}