Kefir = require 'Kefir'
merged = require './merge'
render = require './render'
h = require 'virtual-dom/h'

# Helpers
# ------------------------------------------------------------------------------

randomChoice = (l) -> l[Math.floor(Math.random()*l.length)]

# Workaround since emitter is deprecating
writeTo = (s$, v) ->
    s$.plug Kefir.constant v

# Write an input event to a stream
writeValueTo = (s$) -> (e) ->
    writeTo s$, e.target.value

# Fetch promise to stream
loadJson = (path) ->
    Kefir.fromPromise(fetch(path).then (res) -> res.json())

# Streams
# ------------------------------------------------------------------------------

# TODO: Better way to set these up?
inputs =
    q$: Kefir.pool()
    adder:
        kind$: Kefir.pool()
        age$: Kefir.pool()
        do_add$: Kefir.pool()

# Search q stream
search$ =
    inputs.q$.debounce(250).filter (q) -> q.length > 1

# Searching and results
loadResults = (q) ->
    loadJson '/search?q=' + q
results$ = search$
    .flatMap(loadResults)

# Trees
# TODO: Better encapsulation and eventually abstraction of this "reactive collection"
# that will likely be wanted in the future
tree_id = 0
trees = [{id: tree_id, kind: 'cone', age: 55}]
trees$ = Kefir.pool()
writeTo trees$, trees
removeTree = (t_id) ->
    trees = trees.filter (t) -> t.id != t_id
    writeTo trees$, trees
addTree = (t) ->
    t.id = ++tree_id
    trees.push t
    writeTo trees$, trees

adder$ = merged
    kind: inputs.adder.kind$
    age: inputs.adder.age$
resetAdder = ->
    writeTo inputs.adder.kind$, ''
    writeTo inputs.adder.age$, ''

adder$.sampledBy(inputs.adder.do_add$)
    .onValue addTree
    .onValue resetAdder

# State
# ------------------------------------------------------------------------------

# Merge into a single state object
# TODO: How will nested state work? Should this be one big reduced object?

app$ = merged
    q: inputs.q$
    results: results$
    loading: search$.awaiting(results$)
    trees: trees$
    adder: adder$

# Components
# ------------------------------------------------------------------------------

App = (app) ->
    search_info =
        if app.loading
            'Loading...'
        else if app.results?
            app.results.length + ' results'
        else 'Search for names'

    h 'div', [
        h 'h1', 'Persons'
        Input inputs.q$, app.q
        h 'strong', search_info
        h 'ul', app.results?.map Result
        h 'h1', 'Trees'
        h 'ul', app.trees?.map Tree
        Adder(app.adder)
    ]

Adder = (adder={}) ->
    h 'div', [
        Input inputs.adder.kind$, adder.kind
        Input inputs.adder.age$, adder.age
        Button inputs.adder.do_add$, 'Make tree'
    ]

Input = (input$, value) ->
    oninput = writeValueTo(input$)
    h 'input', {oninput, value}

Button = (input$, text) ->
    onclick = -> writeTo input$, true
    h 'button', {onclick}, text

Result = (s) ->
    h 'li', s

Tree = (t) ->
    h 'li', {onclick: removeTree.bind(null, t.id)}, [
        'the noble '
        h 'strong', t.kind
        ' is '
        h 'em', t.age + ' years old'
    ]

# Going
# ------------------------------------------------------------------------------

render App, app$, document.body
