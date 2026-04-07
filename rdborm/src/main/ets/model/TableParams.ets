import { BuildParams } from "./BuildParams"

/**
 * orm参数
 */
export interface TableParams<T> {
  buildParams: BuildParams<T>
  tableName: string
  fields: string[]
  propertyKeys: string[]
  tableId: string
  propertyId: string
}

