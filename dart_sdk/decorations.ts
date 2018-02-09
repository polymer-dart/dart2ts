
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

export function getOperatorKey(op: IDartOperator): symbol {
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
