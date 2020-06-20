import {Elm} from '@gripeless/elm/source/Entry/SDK'
import * as pico from '@gripeless/pico'

const cachedBodyKey = 'cached-body'
const cachedNotifyEmailKey = 'cached-notify-email'

const params = new URLSearchParams(window.location.search)
const projectName = params.get('project') || 'bungee'

const app = Elm.Entry.SDK.init({
	node: document.getElementById('app'),
	flags: {
		hostname: process.env.HOSTNAME,
		apiURL: process.env.API_URL,
		projectName,
		isDemo: (params.get('demo')) !== null,
		message: null,
		isMac: true,
		cachedBody: localStorage.getItem(cachedBodyKey),
		context: [['page', 'fantastic.com'], ['values', 'ya""\\// man']],
		viewportSize: window.innerWidth + 'x' + window.outerWidth,
		url: window.location.href,
		notifyEmail: [localStorage.getItem(cachedNotifyEmailKey), 'nikersify@nikerino.com']
	}
})

app.ports.focus.subscribe(id => {
	window.requestAnimationFrame(() => {
		const $element = document.getElementById(id)

		if ($element && typeof $element.focus === 'function') {
			$element.focus()
		}
	})
})

app.ports.cacheBody.subscribe(body => {
	localStorage.setItem(cachedBodyKey, body)
})

app.ports.cacheNotifyEmail.subscribe(email => {
	if (email === null) {
		localStorage.removeItem(cachedNotifyEmailKey)
	} else {
		localStorage.setItem(cachedNotifyEmailKey, email)
	}
})

app.ports.getPicoViewportSize.subscribe(id => {
	// Analogous to above
	window.requestAnimationFrame(() => {
		const $element = document.getElementById(id)
		if ($element) {
			const {
				width,
				height
			} = $element.getBoundingClientRect()

			app.ports.gotPicoViewportSize.send({width, height})
		}
	})
})

app.ports.generateScreenshot.subscribe(crop => {
	// Process on the next frame to allow elm side to give time
	// for the elm side to show the loading indicator and such
	window.requestAnimationFrame(() => {
		pico.objectURL(window, {ignore: ['#ignore']}).then(({value: objectURL, errors}) => {
			if (errors.length > 0) {
				console.warn(errors)
			}

			// The real library should crop here, we're too lazy though

			const [[x1, y1], [x2, y2]] = crop

			const width = Math.abs(x1 - x2)
			const height = Math.abs(y1 - y2)

			const canvas = document.createElement('canvas')
			canvas.width = width
			canvas.height = height

			const img = new Image
			img.onload = () => {
				canvas.getContext('2d').drawImage(img, 0, 0)

				canvas.toBlob(blob => {
					const file = new File([blob], 'generated.png')

					app.ports.gotGeneratedScreenshot.send(file)

					URL.revokeObjectURL(objectURL)
				}, 'image/png', 1)
			}

			img.src = objectURL
		}).catch(error => {
			app.ports.gotGeneratedScreenshotError.send(
				error.message||'Unknown error'
			)
		})
	})
})
