import 'slonik'

declare module 'slonik' {
	interface SqlTaggedTemplateType {
		<T = QueryResultRowType>(
			template: TemplateStringsArray,
			...vals: string[]
		): SqlSqlTokenType<T>

		binary: (data: Buffer) => BinarySqlTokenType
	}
}
