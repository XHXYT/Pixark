
export enum ValueType {
    TEXT, INTEGER, LONG, BOOLEAN
}

export default interface ColumnInfo {
    // 实体属性名
    propertyKey: string;

    name: string,
    type: 'TEXT' | 'INTEGER' | 'BOOLEAN' | 'REAL',
    isPrimaryKey?: boolean,
    autoIncrement?: boolean,
    unique?: boolean,
    notNull?: boolean,
    defaultValue?: ValueType
}
