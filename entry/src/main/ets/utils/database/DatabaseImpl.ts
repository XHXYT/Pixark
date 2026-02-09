
import IDatabase from './IDatabase';
import AbsTable from './AbsTable';
import 'reflect-metadata';
import { Context } from '@ohos.arkui.UIContext';
import { Logger } from '../Logger';

/**
 * 缓存数据库中的table
 */
export default class DatabaseImpl implements IDatabase {
    private readonly dbName
    private readonly key
    context: Context

    constructor(dbName: string, context: Context) {
        this.dbName = dbName
        this.context = context
        this.key = "table_map_" + this.dbName
    }

    getTable<T extends AbsTable<any>>(tableClass: { new (context: Context, dbName: string, tableName: string): T }): T {
        let tableName = Reflect.getMetadata('TableName', tableClass)
        // 参数顺序：context, dbName, tableName
        return new tableClass(this.context, this.dbName, tableName)
    }

}