kefir = require 'kefir'
h = require 'virtual-dom/h'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'
merged = require './merge'

# Helpers
# ------------------------------------------------------------------------------

# Write an input event to a stream
# TODO: Replace emitter
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

renderApp = (state) ->
    search_info =
        if state.loading
            'Loading...'
        else if state.results?
            state.results.length + ' results'
        else 'Search for names'

    h 'div', [
        h 'input', {oninput: writeValueTo(q_stream), value: state.q}
        h 'strong', search_info
        h 'ul', state.results?.map renderResult
    ]

renderResult = (s) ->
    h 'li', s

# Loop
# ------------------------------------------------------------------------------

# Render virtual DOM to real DOM
tree = renderApp(app_state)
rootNode = createElement(tree)
document.body.appendChild rootNode
renderRoot = (state) ->
    newTree = renderApp(state)
    patches = diff(tree, newTree)
    rootNode = patch(rootNode, patches)
    tree = newTree
    return

# Render on every app state change
app_state.onValue renderRoot

