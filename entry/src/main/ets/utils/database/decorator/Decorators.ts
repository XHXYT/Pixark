
import ColumnInfo from '../ColumnInfo';
import 'reflect-metadata';

export function Table(v: {db: string, name: string}): ClassDecorator {
    return (target) => {
        Reflect.defineMetadata('Database', v.db, target);
        Reflect.defineMetadata('TableName', v.name, target);
    };
}

/**
 * 列装饰器，用于定义列的映射规则
 * @param options 列配置选项
 */
export function Column(options: Omit<ColumnInfo, 'propertyKey'>) {
    return function (target: any, propertyKey: string) {
        // 创建完整的列信息
        const columnInfo: ColumnInfo = {
            propertyKey,  // 自动填充属性名
            ...options    // 合并提供的配置
        };
        // 存储到类上，而非原型上
        const columns = Reflect.getMetadata('columns', target.constructor) || [];
        columns.push(columnInfo);
        Reflect.defineMetadata('columns', columns, target.constructor);
        console.debug(`Column decorator: ${propertyKey} stored on ${target.constructor.name}`);
    };
}

export function MyTable(v: {dbName: string, columns: ColumnInfo[]}): ClassDecorator {
    return (target) => {
        Reflect.defineMetadata('dbName', v.dbName, target);
        Reflect.defineMetadata('columns', v.columns, target);
    };
}
