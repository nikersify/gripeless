// Usage:
// <script src="SDK_URL"/>
// import gripeless from '@gripeless/sdk'
//
// gripeless.modal('project-name')

import gripelessCSS from '@gripeless/css'
import Elmito from '@gripeless/elm/source/Entry/SDK'
import * as pico from '@gripeless/pico'
import Bowser from 'bowser'

const ElmitoBambito = Elmito as unknown
const Elm = ElmitoBambito as typeof Elmito['Elm']

if (typeof Elm !== 'object' || typeof Elm.Entry !== 'object') {
	throw new Error('Failed to import elm app')
}

const assertNotNull = <T>(x: T | null, label: string): T => {
	if (x === null) {
		throw new TypeError(`Unexpected \`null\`: ${label}`)
	}

	return x
}

const assertNotUndefined = <T>(x: T | undefined, label: string): T => {
	if (x === undefined) {
		throw new TypeError(`${label} is not defined`)
	}

	return x
}

const hostname = assertNotUndefined(process.env.HOSTNAME, 'HOSTNAME')
const apiURL = assertNotUndefined(process.env.API_URL, 'API_URL')

const brand = 'gripeless'

// Can be unique to current session
const id = `${brand}-${Math.random()
	.toString(32)
	.substring(2)}`

// Must be the same across sessions
const cachedBodyKey = `${brand}-last-body`
const cachedNotifyEmailKey = `${brand}-last-notify-email`

const checkScreenshotSupport = (
	userAgent: string,
	viewportWidth: number
) => {
	const engine = Bowser.getParser(userAgent).getEngine().name

	return (
		(engine === 'Blink' || engine === 'Gecko') && viewportWidth >= 640
	)
}

export const modal = (
	projectName: string,
	meta?: {
		context?: {
			[key: string]: unknown
		}
		isDemo?: Boolean
		email?: string
		message?: string
	}
) => {
	const context: [string, string][] = (meta
		? meta.context
			? Object.entries(meta.context)
			: []
		: []
	).map(([key, value]) => {
		if (typeof value !== 'string') {
			console.warn('Coercing value under key ${key} to String')
			return [key, String(value)]
		}

		return [key, value]
	})

	const prefilledEmail = meta && meta.email ? meta.email : null

	const $container = document.createElement('div')
	$container.id = id
	const cstyle = $container.style

	cstyle.position = 'fixed'
	cstyle.top = '0'
	cstyle.right = '0'
	cstyle.bottom = '0'
	cstyle.left = '0'

	cstyle.zIndex = '8008135'

	const $iframe = document.createElement('iframe')

	$iframe.src = 'about:blank'

	const istyle = $iframe.style
	istyle.border = 'none'

	istyle.position = 'absolute'
	istyle.top = '0'
	istyle.right = '0'
	istyle.bottom = '0'
	istyle.left = '0'

	istyle.width = '100vw'
	istyle.height = '100vh'

	$iframe.addEventListener('load', () => {
		const $idocument = assertNotNull(
			$iframe.contentDocument,
			'$iframe.contentDocument'
		)

		const $iwindow = assertNotNull(
			$iframe.contentWindow,
			'$iframe.contentWindow'
		)

		const $inter = $idocument.createElement('link')
		$inter.rel = 'stylesheet'
		$inter.href = 'https://rsms.me/inter/inter.css'
		$idocument.head.appendChild($inter)

		const $innerStyle = $idocument.createElement('style')
		$innerStyle.innerHTML = gripelessCSS
		$idocument.head.appendChild($innerStyle)

		const attachElm = () => {
			const $elm = $idocument.createElement('div')
			$idocument.body.appendChild($elm)

			const app = Elm.Entry.SDK.init({
				node: $elm,
				flags: {
					isDemo:
						typeof meta?.isDemo === 'boolean'
							? meta.isDemo
							: false,
					hostname,
					apiURL,
					projectName,
					isMac: navigator.platform.indexOf('Mac') === 0,
					supportsScreenshots: checkScreenshotSupport(
						window.navigator.userAgent,
						window.innerWidth
					),
					cachedBody: localStorage.getItem(cachedBodyKey),
					message: meta?.message || null,
					notifyEmail: [
						localStorage.getItem(cachedNotifyEmailKey),
						prefilledEmail
					],
					context,
					viewportSize:
						window.innerWidth + 'x' + window.innerHeight,
					url: window.location.href
				}
			})

			const keyupListener = (e: KeyboardEvent) => {
				app.ports.keyUp.send(e.key)
			}

			$iwindow.addEventListener('keyup', keyupListener)

			// When we're about to yeet out the app - remove body scroll lock
			// & make pointer events pass through on the container
			app.ports.aboutToClose.subscribe(() => {
				$container.style.pointerEvents = 'none'

				$iwindow.removeEventListener('keyup', keyupListener)

				$idocument.addEventListener(
					'animationend',
					() => {
						$container.remove()
					},
					{
						once: true
					}
				)
			})

			app.ports.focus.subscribe(id => {
				// Since the elm app is ran in an iframe we need to proxy
				// `focus` in order to use it inside of the frame rather than
				// the main document.
				// Also running `requestAnimationFrame` here to make sure the
				// element that's requested to be focused is actually on the
				// page.
				$iwindow.requestAnimationFrame(() => {
					const $element = $idocument.getElementById(id)

					if ($element && typeof $element.focus === 'function') {
						$element.focus()
					}
				})
			})

			app.ports.getPicoViewportSize.subscribe(id => {
				// Analogous to above
				$iwindow.requestAnimationFrame(() => {
					const $element = $idocument.getElementById(id)
					if ($element) {
						const {
							width,
							height
						} = $element.getBoundingClientRect()

						app.ports.gotPicoViewportSize.send({width, height})
					}
				})
			})

			app.ports.cacheBody.subscribe(body =>
				window.localStorage.setItem(cachedBodyKey, body)
			)

			app.ports.cacheNotifyEmail.subscribe(maybeEmail =>
				maybeEmail === null
					? window.localStorage.removeItem(cachedNotifyEmailKey)
					: window.localStorage.setItem(
							cachedNotifyEmailKey,
							maybeEmail
					  )
			)

			app.ports.generateScreenshot.subscribe(crop => {
				// Process on the next frame to allow elm side to give time
				// for the elm side to show the loading indicator and such
				window.requestAnimationFrame(async () => {
					const {
						value: objectURL,
						errors
					} = await pico.objectURL(window)

					if (errors.length > 0) {
						console.warn(errors)
					}

					const [[x1, y1], [x2, y2]] = crop

					const width = Math.abs(x1 - x2)
					const height = Math.abs(y1 - y2)

					const canvas = document.createElement('canvas')
					canvas.width = width
					canvas.height = height

					const img = new Image()
					img.addEventListener('load', () => {
						const ctx = assertNotNull(
							canvas.getContext('2d'),
							'canvas context'
						)

						ctx.drawImage(
							img,
							-Math.min(x1, x2),
							-Math.min(y1, y2)
						)

						canvas.toBlob(
							blob => {
								if (blob === null) {
									return app.ports.gotGeneratedScreenshotError.send(
										'Failed to generate image blob'
									)
								}

								const file = new File(
									[blob],
									'generated.png'
								)

								app.ports.gotGeneratedScreenshot.send(file)
								URL.revokeObjectURL(objectURL)
							},
							'image/png',
							1
						)
					})

					img.src = objectURL
				})
			})
		}

		$inter.addEventListener('load', attachElm)
		$inter.addEventListener('error', attachElm)
	})

	$container.appendChild($iframe)
	document.body.appendChild($container)
}

export default {
	modal
}
