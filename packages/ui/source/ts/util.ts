export type Thunk<T> = () => T
export const noop = () => {}

export const assertDefined = (
	value: string | undefined,
	label: string
): string => {
	if (value === undefined) {
		throw new Error(`${label} is not defined`)
	}

	return value
}
