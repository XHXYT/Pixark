import AbsTable from './AbsTable';
import { ValuesBucket } from './AbsTable';
import rdb from '@ohos.data.relationalStore';
import 'reflect-metadata';
import ColumnInfo from './ColumnInfo';
import { Context } from '@kit.AbilityKit';


export default abstract class AutoTable<T> extends AbsTable<T> {

  constructor(context: Context, dbName: string, tableName: string) {
    super(dbName, tableName, context);
    console.debug(`${this.constructor.name}, constructor dbName=${dbName} tableName=${tableName}`);

    // 添加初始化监听
    this.futureDb.then(db => {
      console.debug(`${this.constructor.name}, database initialized successfully`);
    }).catch(error => {
      console.error(`${this.constructor.name}, database initialization failed:${error}`);
    });
  }

  // 将子类返回为实体类
  protected abstract getEntityClass(): new (...args: any[]) => T;

  // 获取所有列(使用实体类而不是DAO类)
  private getAllColumns(): ColumnInfo[] {
    const entityClass = this.getEntityClass();
    const columnMap = new Map<string, ColumnInfo>();
    let currentTarget = entityClass;

    console.log(`${this.constructor.name}, getAllColumns starting with target=${entityClass.name}`);

    // 遍历原型链，收集所有装饰器
    while (currentTarget && currentTarget !== Object.prototype) {
      const currentColumns = Reflect.getMetadata('columns', currentTarget) || [];
      console.log(`${this.constructor.name}, getAllColumns checking${currentTarget.name || currentTarget}, found ${currentColumns.length} columns`);
      // 使用 Map 去重，子类属性优先
      currentColumns.forEach(column => {
        if (!columnMap.has(column.propertyKey)) {
          columnMap.set(column.propertyKey, column);
        }
      });
      currentTarget = Object.getPrototypeOf(currentTarget);
    }
    const columns = Array.from(columnMap.values());
    console.log(`${this.constructor.name}, getAllColumns final result:${JSON.stringify(columns)}`);
    return columns;
  }

  // 获取表的所有列
  getTableColumns(): string[] {
    console.debug(`${this.constructor.name}, getTableColumns called`);
    const columns = this.getAllColumns();
    const result = columns.map(col => col.name || col.propertyKey);
    console.debug(`${this.constructor.name}, getTableColumns result: ${JSON.stringify(result)}`);
    return result;
  }

  // 获取表
  getCreateTableSql(): string {
    console.debug(`${this.constructor.name}, getCreateTableSql called`);

    const tableName = Reflect.getMetadata('TableName', this.constructor);
    console.debug(`${this.constructor.name}, getCreateTableSql tableName from decorator: ${tableName}`);

    const columns = this.getAllColumns();
    console.debug(`${this.constructor.name}, getCreateTableSql columns count: ${columns.length}`);

    if (columns.length === 0) {
      console.error(`${this.constructor.name}, getCreateTableSql ERROR: No columns found! Table will not be created properly.`);
    }

    const columnDefs = columns.map(col => {
      let definition = `${col.name} ${col.type}`;
      if (col.isPrimaryKey) definition += ' PRIMARY KEY';
      if (col.autoIncrement) definition += ' AUTOINCREMENT';
      if (col.unique) definition += ' UNIQUE';
      if (col.notNull) definition += ' NOT NULL';
      if (col.defaultValue !== undefined) {
        definition += ` DEFAULT ${col.defaultValue}`;
      }
      console.debug(`${this.constructor.name}, getCreateTableSql column definition: ${definition}`);
      return definition;
    });

    const sql = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs.join(', ')})`;
    console.debug(`${this.constructor.name}, getCreateTableSql final SQL: ${sql}`);
    return sql;
  }

  // 绑定数据
  bindToValuesBucket(bucket: ValuesBucket, item: T) {
    console.debug(`${this.constructor.name}, bindToValuesBucket called`);
    console.debug(`${this.constructor.name}, bindToValuesBucket item type: ${item.constructor.name}`);
    console.debug(`${this.constructor.name}, bindToValuesBucket item: ${JSON.stringify(item)}`);

    const columns = this.getAllColumns();
    console.debug(`${this.constructor.name}, bindToValuesBucket found ${columns.length} columns`);
    columns.forEach(col => {
      let value = item[col.propertyKey];
      console.debug(`${this.constructor.name}, bindToValuesBucket ${col.propertyKey} raw value: ${value} (type: ${typeof value})`);
      // 对于自增主键且值为 null 的情况，跳过该字段
      if (col.isPrimaryKey && col.autoIncrement && (value === null || value === undefined)) {
        console.debug(`${this.constructor.name}, bindToValuesBucket skipping auto-increment primary key: ${col.propertyKey}`);
        return; // 跳过这个字段，不添加到 bucket
      }
      if (col.type === 'BOOLEAN') {
        value = value ? 1 : 0;
      }
      bucket[col.name || col.propertyKey] = value;
      console.debug(`${this.constructor.name}, bindToValuesBucket set ${col.name || col.propertyKey} = ${value}`);
    });
    console.debug(`${this.constructor.name}, bindToValuesBucket final bucket: ${JSON.stringify(bucket)}`);
  }

  // 创建项
  createItem(cursor: rdb.ResultSet): T {
    console.debug(`${this.constructor.name}, createItem called`);

    const item = {} as T;
    const columns = this.getAllColumns();
    console.debug(`${this.constructor.name}, createItem found ${columns.length} columns`);

    columns.forEach(col => {
      const columnName = col.name || col.propertyKey;
      let value: any;

      try {
        if (col.type === 'INTEGER') {
          value = cursor.getLong(cursor.getColumnIndex(columnName));
        } else if (col.type === 'BOOLEAN') {
          value = cursor.getLong(cursor.getColumnIndex(columnName)) > 0;
        } else { // 默认为 TEXT
          value = cursor.getString(cursor.getColumnIndex(columnName));
        }

        console.debug(`${this.constructor.name}, createItem ${col.propertyKey}(${columnName}) = ${value} (type: ${col.type})`);
        item[col.propertyKey] = value;
      } catch (error) {
        console.error(`${this.constructor.name}, createItem ERROR reading column ${columnName}: ${error}`);
      }
    });

    console.debug(`${this.constructor.name}, createItem result: ${JSON.stringify(item)}`);
    return item;
  }

}

