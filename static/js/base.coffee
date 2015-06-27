kefir = require 'kefir'
merged = require './merge'
render = require './render'
h = require 'virtual-dom/h'

# Helpers
# ------------------------------------------------------------------------------

# Write an input event to a stream
writeValueTo = (s) -> (e) ->
    s.plug kefir.constant e.target.value

# Load some json
loadJson = (path) ->
    kefir.fromPromise(fetch(path).then (res) -> res.json())

# Streams
# ------------------------------------------------------------------------------

# Search q stream
q_stream = kefir.pool()
search_stream =
    q_stream.debounce(250).filter (q) -> q.length > 1

# Searching and results
loadResults = (q) ->
    loadJson '/search?q=' + q
results_stream = search_stream
    .flatMap(loadResults)

# Merge into a single state object
app_state = merged {
    q: q_stream
    results: results_stream
    loading: search_stream.awaiting(results_stream)
}, {
    loading: false
}

# Rendering
# ------------------------------------------------------------------------------

App = (state) ->
    search_info =
        if state.loading
            'Loading...'
        else if state.results?
            state.results.length + ' results'
        else 'Search for names'

    h 'div', [
        h 'input', {oninput: writeValueTo(q_stream), value: state.q}
        h 'strong', search_info
        h 'ul', state.results?.map Result
    ]

Result = (s) ->
    h 'li', s

# Goings

render App, app_state
