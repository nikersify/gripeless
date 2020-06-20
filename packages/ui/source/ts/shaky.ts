import shuffle from 'lodash.shuffle'

const messages = [
	'Contacts list page is always taking so long to load',
	'This drag & drop is activating randomly :/',
	'Login sessions are way too short...',
	'This screen is so cluttered!',
	'Text on this button is barely readable',
	"Site doesn't load properly on MS Edge :(",
	'Page is not working on mobile?',
	'Google authentication seems to not work',
	"Search doesn't find my new items",
	"My personal info isn't syncing properly!",
	'Playback button is really glitchy for me',
	'This link is broken, should it be like this?',
	"I can't subscribe with credit card",
	'Picking payment option sends me to a 404 page',
	'please just look at this mess',
	'Notifications are really delayed',
	'Loading my documents takes wayyy too long',
	'Filter input unfocuses itself when I press shift',
	"App doesn't work offline :(",
	'The coffee service 418 is down :O'
]

const delay = (t: number) => new Promise(resolve => setTimeout(resolve, t))

export const shakyMessages = async (selector: string) => {
	const $container = document.querySelector(selector)

	if ($container === null) {
		throw new TypeError(
			`Failed to locate element with selector \`${selector}\``
		)
	}

	const generateds: {left: number[]; right: number[]} = {
		left: [],
		right: []
	}

	const shuffled = shuffle(messages)
		.slice(0, 18)
		.map(
			(value, index) =>
				[index % 2 === 0 ? 'left' : 'right', value] as const
		)

	await delay(500)
	for (const [side, message] of shuffled) {
		const $shaky = document.createElement('div')

		$shaky.classList.add(
			'absolute',
			'shake',
			'text-sm',
			'pointer-events-auto',
			'select-none'
		)

		$shaky.innerText = `"${message}"`

		const x = Math.random() * 15 + 3

		let y: number | undefined = undefined
		let i = 0
		while (y === undefined) {
			const generated = Math.round(Math.random() * 85)

			if (
				generateds[side].every(gy => {
					return Math.abs(gy - generated) > 6
				})
			) {
				y = generated
			}

			if (i > 100) {
				break
			}

			i++
		}

		if (y === undefined) {
			break
		}

		generateds[side].push(y)

		$shaky.style[side] = x + '%'
		$shaky.style.top = y + '%'

		$container.appendChild($shaky)

		await delay(800 + Math.random() * 1000)
	}
}
