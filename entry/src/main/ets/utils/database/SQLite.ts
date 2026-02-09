
import DatabaseImpl from './DatabaseImpl';
import ITable from './ITable';
import AbsTable from './AbsTable';
import 'reflect-metadata';
import { Context } from '@ohos.arkui.UIContext';
import { Logger } from '../Logger';


/**
 * 数据库封装
 */
export default class SQLite {

    static context: Context

    static init(context: Context) {
        this.context = context
    }

    /**
     * 传入数据库表类，获取对应的表对象，进行相应的增删改查操作
     * @param tableClass
     */
    static with<T extends AbsTable<any>>(tableClass: { new (context: Context, dbName: string, tableName: string): T }): T {
        let dbName = Reflect.getMetadata('Database', tableClass)
        if (!dbName) {
            throw new Error('table db is empty')
        }
        Logger.getInstance().debug('SQLite','dbName = ', dbName)
        let database = new DatabaseImpl(dbName, this.context)
        return database.getTable(tableClass)
    }

}