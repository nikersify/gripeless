import {UserInputError} from 'apollo-server-express'
import * as fp from 'fp-ts'
import * as t from 'io-ts'
import {
	PrimitiveValueExpressionType,
	QueryResultRowType,
	SqlSqlTokenType,
	SqlTaggedTemplateType,
	SqlTokenType,
	ValueExpressionType,
	sql
} from 'slonik'

import {parseOrThrow} from './util'

type SafeStringBrand = {
	readonly SafeString: unique symbol
}

type SafeNumberBrand = {
	readonly SafeNumber: unique symbol
}

type SafeNumber = t.Branded<number, SafeNumberBrand>
type SafeString = t.Branded<string, SafeStringBrand>

type Safe = SafeString | SafeNumber

// Various safe constructors
const safeStringLiteral = parseOrThrow(
	t.brand(
		t.string,
		(str): str is SafeString => true,
		`SafeString (${0}, ${1})`
	)
)

const safeStringLength = (minLength: number, maxLength: number) =>
	t.brand(
		t.string,
		(str): str is SafeString =>
			str.length >= minLength && str.length <= maxLength,
		`SafeString (${minLength}, ${maxLength})`
	)

const safeNumberBounded = (min: number, max: number) =>
	parseOrThrow(
		t.brand(
			t.number,
			(n): n is SafeNumber => n >= min && n <= max,
			`SafeNumber (${min}, ${max})`
		)
	)

const safeNumberDivisibleBy = (divisor: number) =>
	parseOrThrow(
		t.brand(
			t.number,
			(n): n is SafeNumber => n % divisor === 0,
			`SafeNumber (div by ${divisor})`
		)
	)

const safeSql = <T = QueryResultRowType>(
	template: TemplateStringsArray,
	...vals: Safe[]
): SqlSqlTokenType<T> => sql(template, ...vals)

const a = safeNumberDivisibleBy(2)(safeNumberBounded(0, 10)(5))
const b = safeStringLiteral('hei')

const o = safeSql`select shit from somewhree where shit > ${a} ${b}`
