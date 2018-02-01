// Some triks borrowed from dart_sdk

// Extend global Array
import {initCollections} from './collection';
import {initAsync} from "./async";
import {initNatives} from "./natives";

/// Init
initCollections();
initAsync();
initNatives();

export function invokeMethod(o: any, method: string | symbol, ...args: Array<any>): any {
    o = o || this;

    // Lookup for override
    let m: IDartMetadata = getDartMetadata(o.constructor);

    if (m != null && m.methodOverrides.has(method)) {
        method = m.methodOverrides.get(method);
    }

    return o[method].apply(o, args);
}


export const metadata = Symbol('metadata');

export class DartObject {
    [metadata](): any {

    }
}

const DartMetadataKey = Symbol.for('dart:metadata');

export interface IDartMetadata {
    library?: string;
    operators?: Map<symbol, Function>;
    methodOverrides?: Map<string | symbol, string | symbol>;
    propertyOverrides?: Map<string | symbol, string | symbol>;
}

export function DartMetadata(m: IDartMetadata): ClassDecorator {
    return (target) => {
        getDartMetadata(target).library = m.library;
    }
}

export function OverrideMethod(newName: string | symbol): MethodDecorator {
    return (target, name, descriptor) => {
        getDartMetadata(target.constructor).methodOverrides.set(newName, name);
    };
}

export function OverrideProperty(newName: string | symbol): PropertyDecorator {
    return (target, name) => {
        getDartMetadata(target.constructor).propertyOverrides.set(newName, name);
    };
}

export enum OperatorType {
    BINARY,
    PREFIX,
    SUFFIX
}

export interface IDartOperator {
    op: string;
    type: OperatorType;
}

export function DartOperator(op: IDartOperator): MethodDecorator {
    return (target, name, descriptor) => {
        let meta: IDartMetadata = getDartMetadata(target.constructor);
        let maps = meta.operators;
        let k: symbol = getOperatorKey(op);
        maps.set(k, <any>descriptor.value);
    }
}

function getOperatorKey(op: IDartOperator): symbol {
    return Symbol.for(`dart:operand:${op.type}:${op.op}`);
}

export function getDartMetadata(t): IDartMetadata {
    // TODO: investigate if this could return super class meta if current is not found
    // but maybe this is not necessary because of js inheritance
    let meta: IDartMetadata = t[DartMetadataKey];
    if (meta == null) {
        t[DartMetadataKey] = meta = {
            operators: new Map(),
            methodOverrides: new Map(),
            propertyOverrides: new Map()
        };
    }
    return meta;
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

/**
 * Read a property with overrides
 * @param obj
 * @param {string | symbol} prop
 * @returns {any}
 */
export function readProperty(obj: any, prop: string | symbol) {
    // Lookup for override
    let m: IDartMetadata = getDartMetadata(obj.constructor);

    if (m != null && m.propertyOverrides.has(prop)) {
        prop = m.methodOverrides.get(prop);
    }
    return obj[prop];
}

/**
 * Write a property with overrides
 * @param obj
 * @param {string | symbol} prop
 * @param val
 */
export function writeProperty(obj: any, prop: string | symbol, val: any) {
    // Lookup for override
    let m: IDartMetadata = getDartMetadata(obj.constructor);

    if (m != null && m.propertyOverrides.has(prop)) {
        prop = m.methodOverrides.get(prop);
    }
    obj[prop] = val;
}

function getOrCompute<K, V>(m: Map<K, V>, k: K, orElse: (k?: K) => V) {

    if (m.has(k)) {
        return m.get(k);
    }
    let v: V = orElse(k);
    m.set(k, v);
    return v;
}

/// This is the op func cache (see below)
const opCache: Map<OperatorType, Map<String, (target) => any>> = new Map([
    [OperatorType.BINARY, new Map()],
    [OperatorType.PREFIX, new Map()],
    [OperatorType.SUFFIX, new Map()]
]);

/**
 * Call a generic binary operator.
 *
 * This method will search in metadata for a suitable operator
 * @param {string} op the operator name
 * @param {T} left the left argument
 * @param right the right argument
 * @returns {T} the result
 */
export function invokeBinaryOperand<T>(op: string, left: T, right: any): T {
    if (typeof left == 'object') {
        let meta: IDartMetadata = getDartMetadata(left.constructor);
        if (meta != null && meta.operators != null) {
            let f = meta.operators.get(getOperatorKey({type: OperatorType.BINARY, op: op}));
            if (f != null) {
                return f.call(left, right);
            }
        }

        throw `Cant apply operator '${op}' to ${left} and ${right}`;
    }

    return getOrCompute(opCache.get(OperatorType.BINARY), op, (o) => {
        if (o == '~/') {
            return (a, b) => Math.trunc(a / b);
        }
        return eval(`(function(a,b) { return a ${o} b; })`);
    })(left, right);
}

/**
 * Invoke an unary operator taking care of overrides.
 * @param {string} op
 * @param {OperatorType} type
 * @param {T} target
 * @returns {T}
 */
export function invokeUnaryOperand<T>(op: string, type: OperatorType, target: T): T {
    if (typeof target == 'object') {
        let meta: IDartMetadata = getDartMetadata(target.constructor);
        if (meta != null && meta.operators != null) {
            let f = meta.operators.get(getOperatorKey({type: type, op: op}));
            if (f != null) {
                return f.call(target);
            }
        }

        throw `Cant apply operator '${op}' to ${target}`;
    }

    return getOrCompute(opCache.get(type), op, (o) => {
        switch (type) {
            case OperatorType.SUFFIX:
                return eval(`(function() { return this${o}; })`);
            case OperatorType.PREFIX:
                return eval(`(function() { return ${o}this; })`);
        }
        throw "Invalid type : ${type}";
    }).call(target);
}