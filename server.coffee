somata_socketio = require 'somata-socketio'

app = somata_socketio.setup_app
    port: 10145
    metaserve: compilers:
        css: require('metaserve-css-styl')()
        js: require('metaserve-js-coffee-reactify')(ext: 'coffee')

app.get '/', (req, res) -> res.render 'base'

all_names = "joe james jack jillian jeffrey george fred frank frida".split(' ')
app.get '/search', (req, res) ->
    {q} = req.query
    respond = ->
        res.json all_names.filter (n) -> n.match q
    setTimeout respond, 500

app.start()
