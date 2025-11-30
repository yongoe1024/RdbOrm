import { BuildParams } from "./BuildParams"

/**
 * orm参数
 */
export interface TableParams<T> {
  buildParams: BuildParams<T>
  tableName: string
  fields: Record<string, string>
  propertyKeys: Record<string, string>
}

