export const addCrisp = () => {
	//@ts-ignore
	window.$crisp = []

	//@ts-ignore
	window.CRISP_WEBSITE_ID = 'fcb5423d-9262-440f-822f-90c7dab7ad73'

	const script = document.createElement('script')
	script.src = 'https://client.crisp.chat/l.js'
	script.async = true
	document.head.appendChild(script)
}
