import AbsTable from './AbsTable';
import { ValuesBucket } from './AbsTable';
import rdb from '@ohos.data.relationalStore';
import 'reflect-metadata';
import ColumnInfo from './ColumnInfo';
import { Context } from '@kit.AbilityKit';
import { createLogger } from '../Logger';

const logger = createLogger('AutoTable');

export default abstract class AutoTable<T> extends AbsTable<T> {
  constructor(context: Context, dbName: string, tableName: string) {
    super(dbName, tableName, context);
    logger.debug(`${this.constructor.name}, constructor dbName=${dbName} tableName=${tableName}`);

    this.futureDb.then(db => {
      logger.debug(`${this.constructor.name}, database initialized successfully`);
    }).catch(error => {
      logger.error(`${this.constructor.name}, database initialization failed:${error}`);
    });
  }

  // 将子类返回为实体类
  protected abstract getEntityClass(): Function;

  // 获取所有列(使用实体类而不是DAO类)
  private getAllColumns(): ColumnInfo[] {
    const entityClass = this.getEntityClass();
    const columnMap = new Map<string, ColumnInfo>();
    let currentTarget = entityClass;
    logger.debug(`${this.constructor.name}, getAllColumns starting with target=${entityClass.name}`);

    // 遍历原型链，收集所有装饰器
    while (currentTarget && currentTarget !== Object.prototype) {
      const currentColumns = Reflect.getMetadata('columns', currentTarget) || [];
      logger.debug(`${this.constructor.name}, getAllColumns checking ${currentTarget.name || currentTarget}, found ${currentColumns.length} columns`);

      // 使用 Map 去重，子类属性优先
      currentColumns.forEach(column => {
        if (!columnMap.has(column.propertyKey)) {
          columnMap.set(column.propertyKey, column);
        }
      });
      currentTarget = Object.getPrototypeOf(currentTarget);
    }

    const columns = Array.from(columnMap.values());
    logger.debug(`${this.constructor.name}, getAllColumns final result:${JSON.stringify(columns)}`);
    return columns;
  }

  // 获取表的所有列名
  getTableColumns(): string[] {
    logger.debug(`${this.constructor.name}, getTableColumns called`);
    const columns = this.getAllColumns();
    const result = columns.map(col => col.name || col.propertyKey);
    logger.debug(`${this.constructor.name}, getTableColumns result: ${JSON.stringify(result)}`);
    return result;
  }

  // 获取建表 SQL
  getCreateTableSql(): string {
    logger.debug(`${this.constructor.name}, getCreateTableSql called`);
    const tableName = Reflect.getMetadata('TableName', this.constructor);
    const columns = this.getAllColumns();

    if (columns.length === 0) {
      logger.error(`${this.constructor.name}, getCreateTableSql ERROR: No columns found!`);
      return '';
    }

    const columnDefs = columns.map(col => {
      let definition = `${col.name} ${col.type}`;
      if (col.isPrimaryKey) definition += ' PRIMARY KEY';
      if (col.autoIncrement) definition += ' AUTOINCREMENT';
      if (col.unique) definition += ' UNIQUE';
      if (col.notNull) definition += ' NOT NULL';

      // 字符串类型的 defaultValue 必须加上单引号，否则 SQL 会报错
      if (col.defaultValue !== undefined) {
        if (col.type === 'TEXT') {
          definition += ` DEFAULT '${col.defaultValue}'`;
        } else {
          definition += ` DEFAULT ${col.defaultValue}`;
        }
      }

      return definition;
    });

    const sql = `CREATE TABLE IF NOT EXISTS ${tableName} (${columnDefs.join(', ')})`;
    logger.debug(`${this.constructor.name}, getCreateTableSql final SQL: ${sql}`);
    return sql;
  }

  // 重写初始化方法：建表后自动执行迁移
  protected async init(db: rdb.RdbStore): Promise<void> {
    // 先尝试创建表（如果表不存在则创建）
    await db.executeSql(this.getCreateTableSql());
    const createSql = this.getCreateTableSql();
    logger.info(`[DB_INIT] 准备建表 SQL: ${createSql}`);
    await db.executeSql(createSql);
    // 自动迁移（如果表已存在，对比并新增缺失的列）
    logger.info(`[DB_INIT] 建表成功，准备检查迁移...`);
    await this.autoMigrate(db);
  }

  /**
   * 自动迁移逻辑
   * 对比代码定义的列和数据库中实际的列，自动执行 ALTER TABLE ADD COLUMN
   */
  private async autoMigrate(db: rdb.RdbStore): Promise<void> {
    try {
      const existingColumns = await this.getExistingColumns(db);
      logger.info(`[DB_MIGRATE] 数据库中已存在的列: ${existingColumns.join(',')}`);
      const definedColumns = this.getAllColumns();

      for (const col of definedColumns) {
        const colName = col.name || col.propertyKey;
        if (!existingColumns.includes(colName)) {
          let alterSql = `ALTER TABLE ${this.tableName} ADD COLUMN ${colName} ${col.type}`;
          if (col.notNull) alterSql += ' NOT NULL';
          if (col.defaultValue !== undefined) {
            if (col.type === 'TEXT') {
              alterSql += ` DEFAULT '${col.defaultValue}'`;
            } else {
              alterSql += ` DEFAULT ${col.defaultValue}`;
            }
          } else if (col.notNull) {
            if (col.type === 'TEXT') alterSql += " DEFAULT ''";
            else if (col.type === 'INTEGER' || col.type === 'REAL') alterSql += " DEFAULT 0";
          }
          logger.info(`[DB_MIGRATE] 准备执行迁移 SQL: ${alterSql}`);
          await db.executeSql(alterSql);
          logger.info(`[DB_MIGRATE] 迁移成功: ${colName}`);
        }
      }
    } catch (error) {
      logger.error(`[DB_MIGRATE] 迁移失败详细错误:`, error);
    }
  }

  /**
   * 查询数据库中当前表已存在的列名
   */
  private async getExistingColumns(db: rdb.RdbStore): Promise<string[]> {
    const resultSet = await db.querySql(`PRAGMA table_info('${this.tableName}')`);
    const columns: string[] = [];

    if (resultSet.goToFirstRow()) {
      do {
        // PRAGMA table_info 返回的列中，索引为 1 的是列名
        const colName = resultSet.getString(1);
        columns.push(colName);
      } while (resultSet.goToNextRow());
    }

    resultSet.close();
    return columns;
  }

  // 绑定数据
  bindToValuesBucket(bucket: ValuesBucket, item: T) {
    logger.debug(`${this.constructor.name}, bindToValuesBucket called`);
    const columns = this.getAllColumns();

    columns.forEach(col => {
      let value = item[col.propertyKey];

      // 对于自增主键且值为 null 的情况，跳过该字段
      if (col.isPrimaryKey && col.autoIncrement && (value === null || value === undefined)) {
        return;
      }

      if (col.type === 'BOOLEAN') {
        value = value ? 1 : 0;
      }

      bucket[col.name || col.propertyKey] = value;
    });
  }

  // 创建项
  createItem(cursor: rdb.ResultSet): T {
    logger.debug(`${this.constructor.name}, createItem called`);
    const EntityClass = this.getEntityClass() as new () => T;
    const item = new EntityClass();
    const columns = this.getAllColumns();

    columns.forEach(col => {
      const columnName = col.name || col.propertyKey;
      let value: any;
      try {
        if (col.type === 'INTEGER') {
          value = cursor.getLong(cursor.getColumnIndex(columnName));
        } else if (col.type === 'BOOLEAN') {
          value = cursor.getLong(cursor.getColumnIndex(columnName)) > 0;
        } else {
          // 默认为 TEXT
          value = cursor.getString(cursor.getColumnIndex(columnName));
        }
        item[col.propertyKey] = value;
      } catch (error) {
        logger.error(`${this.constructor.name}, createItem ERROR reading column ${columnName}:`, error);
      }
    });

    return item;
  }

}
