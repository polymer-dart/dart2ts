export function callMethod(target:any,name:string,args:Array<any>):any {
   return (<Function>(target[name])).apply(target,args);
}

export function getProperty(target:any,name:string):any {
    return target[name];
}

export function setProperty(target:any,name,string,value:any):void {
    target[name] = value;
}