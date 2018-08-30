import {copyProps} from "./utils";

const DartMetadataKey = Symbol.for('dart:metadata');

export interface IDartMetadata {
    library?: string;
    operators?: Map<symbol, Function>;
    methodOverrides?: Map<string | symbol, string | symbol>;
    propertyOverrides?: Map<string | symbol, string | symbol>;
    annotations?: Array<IAnnotation>;
    propertyAnnotations?: Map<string | symbol, Map<string, Array<any>>>;
}

function isPropertyOf(prototype: object, name: PropertyKey): boolean {
    return prototype.hasOwnProperty(name) || (prototype.constructor != Object && isPropertyOf(prototype.constructor.prototype, name));
}

/**
 * Merge metadatas. The merging strategy is : the first wins, arrays get appended
 * @param {IDartMetadata} metadatas
 * @returns {IDartMetadata}
 */
function mergeMetadata(...metadatas: Array<IDartMetadata>): IDartMetadata {
    let dest: IDartMetadata = {
        operators: new Map(),
        methodOverrides: new Map(),
        propertyOverrides: new Map<string | symbol, string | symbol>(),
        annotations: [],
        propertyAnnotations: new Map<string | symbol, Map<string, Array<any>>>()
    };

    metadatas.forEach((m) => {
        dest.library = dest.library || m.library;
        mergeMaps(dest.methodOverrides, m.methodOverrides);
        mergeMaps(dest.propertyOverrides, m.propertyOverrides);
        if (m.annotations) {
            dest.annotations.push(...m.annotations);
        }

        m.propertyAnnotations.forEach((annoMap, prop) => {

            let destAnnoMap: Map<string, Array<any>> = dest.propertyAnnotations.get(prop);
            if (destAnnoMap == null) {
                destAnnoMap = new Map<string, Array<any>>();
                dest.propertyAnnotations.set(prop, destAnnoMap);
            }

            destAnnoMap.forEach((annos, annoKey) => {
                let destAnnos = destAnnoMap.get(annoKey);
                if (destAnnos == null) {
                    destAnnos = [];
                    destAnnoMap.set(annoKey, destAnnos);
                }

                destAnnos.push(...annos);
            });


        });

    });


    return dest;
}

function mergeMaps<K, V>(dst: Map<K, V>, src: Map<K, V>) {

    if (src === null || src === undefined || dst === null || dst === undefined) {
        return;
    }

    src.forEach((v, k) => {
        if (!dst.has(k)) {
            dst.set(k, v);
        }
    });

}

export function DartMetadata(m: IDartMetadata): ClassDecorator {
    return <T extends { new(...any): any }>(target) => {
        let meta: IDartMetadata = getDartMetadata(target);
        let getter = meta && meta.operators && meta.operators.get(getOperatorKey({type: OperatorType.BINARY, op: '[]'}));
        let setter = meta && meta.operators && meta.operators.get(getOperatorKey({type: OperatorType.BINARY, op: '[]='}));


        return new Proxy(target, {
            construct(target: T, args) {
                return new Proxy(new target(...args), {
                    get(target, prop) {

                        // if there isn't a prop => try with indexed operator
                        if (getter && !isPropertyOf(target, prop)) {
                            // If there is one use it
                            return getter.call(target, prop);
                        }

                        // Get it in the normalway
                        return target[prop];
                    },

                    set(target, prop, val): boolean {

                        if (setter && !isPropertyOf(target, prop)) {
                            setter.call(target, prop, val);

                        } else {
                            target[prop] = val;
                        }
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

/*
export interface ConstructorOf<B> {
    new(...args): B,

    prototype: B
}*/

export type ConstructorOf<X extends object> = {
    new(...args): X;
    prototype: X;
};

/**
 *
 * Mixes one base class with a mixin, merging metadata.
 *
 * To be extended to map polymer mixin. One option is allowing `m` to be a function instead of a constructor
 * (to distinguish one can check if there is any dartmetadata (normal dart class) or not (normal js function)).
 * In the case of a normal function that function will be used insted of merging.
 *
 * @param {ConstructorOf<M extends object>} m
 * @param {ConstructorOf<B extends object>} b
 * @returns {ConstructorOf<M & B>}
 */
export function dartMixin<BC extends ConstructorOf<any>, MC extends ConstructorOf<any>>(b: BC, m: MC): BC & MC {

    // IF m is a native mixin use it
    if (m[DartMetadataKey] === undefined) {
        return (m as Function)(b) as BC & MC;
    }

    let mixin = class extends (b as ConstructorOf<any>) {

        constructor(...args) {
            super(...args);
            // Apply mixin constructor too
            m.apply(this, args);
        }
    };

    // Copy prototype props
    copyProps(m.prototype, mixin.prototype);
    // And statics too
    copyProps(m, mixin);


    // set metadata
    setDartMetadata(mixin, mergeMetadata(getDartMetadata(b), getDartMetadata(m)));

    return mixin as BC & MC;
}


export function dartMixins<X extends object>(b, ...mixins): ConstructorOf<X> {
    let res = b;
    mixins.forEach((m) => {
        res = dartMixin(res, m);
    });
    return res;
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

function setDartMetadata(t, m: IDartMetadata): void {
    t[DartMetadataKey] = m;
}
