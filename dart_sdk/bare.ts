// Some triks borrowed from dart_sdk

// Extend global Array
import {initCollections} from './collection';
import {initAsync} from "./async";
import {initNatives} from "./natives";


/// Init
initCollections();
initAsync();
initNatives();

export function invokeMethod(o: any, method: string, ...args: Array<any>): any {
    o = o || this;
    return o[method].apply(o, args);
}


export const metadata = Symbol('metadata');

export class DartObject {
    [metadata](): any {

    }
}

const DartMetadataKey = Symbol.for('dart:metadata');

export interface IDartMetadata {
    library: string;
}

export function DartMetadata(m: IDartMetadata): ClassDecorator {
    return (target) => Object.defineProperty(target, DartMetadataKey, {
        get: () => m
    });
}

export function getDartMetadata(t): IDartMetadata {
    return t[DartMetadataKey];
}


export let init: symbol = Symbol();


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
        '~/': (a, b) => Math.trunc(a / b),
        '==': (a, b) => a == b
    }[op](left, right);
}