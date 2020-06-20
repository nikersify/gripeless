const sanitizeInput = (input: string) =>
	input
		.replace(/'/g, "''")
		.replace(/\\/g, '\\\\')
		.replace(/"/g, '\\"')

const toString = (input: string) => {
	return sanitizeInput(input)
}

type HStore = [string, string][]

export const stringify = (data: HStore): string => {
	const hstore = data.map(([key, value]) => {
		return `"${toString(key)}"=>"${toString(value)}"`
	})

	return hstore.join(',')
}

export const parse = (data: string): HStore => {
	const result: {[key: string]: string} = {}

	// Using [\s\S] to match any character, including line feed and carriage return,
	const r = /(["])(?:\\\1|\\\\|[\s\S])*?\1|NULL/g
	const matches = data.match(r)
	const clean = (value: string) =>
		value
			// Remove leading double quotes
			.replace(/^\"|\"$/g, '')
			// Unescape quotes
			.replace(/\\"/g, '"')
			// Unescape backslashes
			.replace(/\\\\/g, '\\')
			// Unescape single quotes
			.replace(/''/g, "'")

	if (matches) {
		for (let i = 0, l = matches.length; i < l; i += 2) {
			if (matches[i] && matches[i + 1]) {
				var key = clean(matches[i])
				var value = matches[i + 1]
				if (value !== 'NULL') {
					result[key] = clean(value)
				}
			}
		}
	}

	return Object.entries(result)
}
