import {inspect} from 'util'

import {NextFunction, Request, RequestHandler, Response} from 'express'
import {compact, last} from 'fp-ts/lib/Array'
import {isLeft} from 'fp-ts/lib/Either'
import {Option, fold, map} from 'fp-ts/lib/Option'
import {pipe} from 'fp-ts/lib/pipeable'
import * as t from 'io-ts'
import {PathReporter} from 'io-ts/lib/PathReporter'

export const nullable = <T extends t.Any>(x: T) => t.union([t.null, x])

export const niceParseError = (
	error: t.ValidationError
): Option<string> => {
	const path = error.context
		.map(c => c.key)
		.filter(key => key.length > 0)
		.join('.')

	const maybeErrorContext = last(
		// https://github.com/gcanti/fp-ts/pull/544
		error.context as t.ContextEntry[]
	)

	return pipe(
		maybeErrorContext,
		map(errorContext => {
			const expectedType = errorContext.type.name
			return (
				`Expecting ${expectedType}` +
				(path === '' ? '' : ` at ${path}`) +
				` but instead got: ${inspect(error.value)}.`
			)
		})
	)
}

export const parseOrThrow = <A, O, I>(
	codec: t.Type<A, O, I>,
	error: new (message: string) => any = TypeError
) => (data: I) => {
	const result = codec.decode(data)

	if (isLeft(result)) {
		throw new error(
			compact(result.left.map(niceParseError)).join('\n')
		)
	}

	return result.right
}

export type WrapHandler = (
	req: Request,
	res: Response,
	next: NextFunction
) => Promise<any>

export const wrap: (handler: WrapHandler) => RequestHandler = handler => (
	req: Request,
	res: Response,
	next: NextFunction
): any => handler(req, res, next).catch(next)
