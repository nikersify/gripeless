const fs = require('fs')
const https = require('https')

const requestListener = (req, res) => {
	res.setHeader('Access-Control-Allow-Origin', '*')
	res.setHeader('Cache-Control', 'no-cache')
	res.setHeader('Content-Type', 'text/javascript')

	res.end(fs.readFileSync('./dist/index.js'))
}

const port = 1212
https
	.createServer(
		{
			key: fs.readFileSync(
				'../../cert/supers.localhost+1-key.pem',
				'utf8'
			),
			cert: fs.readFileSync(
				'../../cert/supers.localhost+1.pem',
				'utf8'
			)
		},
		requestListener
	)
	.listen(port, '127.0.0.1', () =>
		console.log(`[serve] listening on port ${port}`)
	)
