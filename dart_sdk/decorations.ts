const DartMetadataKey = Symbol.for('dart:metadata');

export interface IDartMetadata {
    library?: string;
    operators?: Map<symbol, Function>;
    methodOverrides?: Map<string | symbol, string | symbol>;
    propertyOverrides?: Map<string | symbol, string | symbol>;
    annotations?: Array<IAnnotation>;
    propertyAnnotations?: Map<string | symbol, Map<string, Array<any>>>;
}

export function DartMetadata(m: IDartMetadata): ClassDecorator {
    return <T extends { new(...any): any }>(target) => {
        getDartMetadata(target).library = m.library;

        return new Proxy(target, {
            construct(target: T, args) {
                return new Proxy(new target(...args), {
                    get(target, prop) {
                        return target[prop];
                    },

                    set(target, prop, val): boolean {
                        target[prop] = val;
                        return true;
                    }
                });
            }
        });
    }
}

export interface IAnnotation {
    library: string;
    type: string;
    value?: any;
}

export interface IAnnotationKey {
    library: string;
    type: string;
}

export function DartClassAnnotation(anno: IAnnotation): ClassDecorator {
    return (target) => {
        getDartMetadata(target).annotations.push(anno);
    }
}

export function DartMethodAnnotation(anno: IAnnotation): MethodDecorator {
    return (target, name, descriptor) => registerPropAnno(anno, target, name);
}

let registerPropAnno: (anno: IAnnotation, target: Object, name: string | symbol) => void = (anno: IAnnotation, target: Object, name: string | symbol) => {
    let md: IDartMetadata = getDartMetadata(target.constructor);

    let propAnnos: Map<string, Array<any>> = md.propertyAnnotations.get(name);
    if (propAnnos == null) {
        propAnnos = new Map<string, Array<any>>();
        md.propertyAnnotations.set(name, propAnnos);
    }

    let key: string = `{${anno.library}}#{${anno.type}}`;
    let values: Array<any> = propAnnos.get(key);
    if (values == null) {
        values = [];
        propAnnos.set(key, values);
    }

    values.push(anno.value);
};

export function DartPropertyAnnotation(anno: IAnnotation): PropertyDecorator {
    return (target, name) => registerPropAnno(anno, target, name);
}

export function OverrideMethod(newName: string | symbol, oldName?: string): MethodDecorator {
    return (target, name, descriptor) => {
        getDartMetadata(target.constructor).methodOverrides.set(newName, oldName || name);
    };
}

export function OverrideProperty(newName: string | symbol, oldName?: string): PropertyDecorator {
    return (target, name) => {
        getDartMetadata(target.constructor).propertyOverrides.set(newName, oldName || name);
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
            propertyOverrides: new Map(),
            annotations: [],
            propertyAnnotations: new Map<string | symbol, Map<string, Array<any>>>()
        };
    }
    return meta;
}
