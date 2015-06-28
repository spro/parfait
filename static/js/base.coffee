Kefir = require 'Kefir'
merged = require './merge'
render = require './render'
keywords = require './keywords'
h = require 'virtual-dom/h'
somata = require './somata-socketio'

# Helpers
# ------------------------------------------------------------------------------

somata_subscribe = (args...) ->
    Kefir.stream (emitter) ->
        somata.subscribe args..., (event) ->
            emitter.emit event

randomChoice = (l) -> l[Math.floor(Math.random()*l.length)]

# Turn an object into an array of [k, v] pairs
pairs = (obj) ->
    keys = Object.keys(obj)
    length = keys.length
    ps = Array(length)
    i = 0
    while i < length
        ps[i] = [
            keys[i]
            obj[keys[i]]
        ]
        i++
    ps

# Turn an object into an array of [k, v] pairs sorted by v (descending)
sorted_pairs = (o) ->
    ps = pairs(o)
    ps.sort ([k1, v1], [k2, v2]) -> v2 - v1

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
routes =
    page$: Kefir.fromEvents(window, 'hashchange').merge(Kefir.fromEvents(window, 'load')).map(-> window.location.hash.replace(/^#/, '')).log '[onhashchange]'
inputs =
    q$: Kefir.pool()
    adder:
        kind$: Kefir.pool()
        age$: Kefir.pool()
        do_add$: Kefir.pool()
    tweets_going$: Kefir.pool()
    tweets_media$: Kefir.pool()
    tweets_watching$: Kefir.pool()

# Search q stream
search$ =
    inputs.q$.debounce(250).filter (q) -> q.length > 1

# Searching and results
loadResults = (q) ->
    loadJson '/search?q=' + q
results$ = search$
    .flatMap(loadResults)

# Selected keywords
selected_keywords$ = Kefir.pool()
selectKeyword = (w) -> writeTo selected_keywords$, [w]
unselectKeyword = (w) -> writeTo selected_keywords$, []

# Filtering tweet stream by selected keywords
filterTweet = (t, ks) ->
    console.log 'my ks are', ks
    text_keywords = keywords t.text
    for k in ks
        if k in text_keywords then return true
    return false

# Tweet stream
tweet$ = somata_subscribe('twitter', 'tweet')
    .filterBy inputs.tweets_going$
tweet_options$ = merged
    tweets_going: inputs.tweets_going$
    tweets_media: inputs.tweets_media$
    tweets_watching: inputs.tweets_watching$
    selected_keywords: selected_keywords$
tweets$ = tweet_options$.flatMapLatest((opts) ->
    tweet$
        .filter (t) ->
            if !opts.tweets_watching then return false
            if !opts.tweets_media then return true
            else return t.entities.media?
        .filter (t) ->
            if opts.selected_keywords.length == 0 then return true
            else return filterTweet t, opts.selected_keywords
).slidingWindow(20)

# Word counting
word$ = tweet$.map((t) -> t.text).map(keywords).flatten()
count = (counts, word) ->
    counts[word] ||= 0
    counts[word] +=  1
    counts
word_count$ = word$.scan(count, {})

# Trees
# TODO: Better encapsulation and eventually abstraction of this "reactive collection"
# that will likely be wanted in the future
tree_id = 0
trees = [{id: tree_id, kind: 'cone', age: 55}]
trees$ = Kefir.pool()
removeTree = (t_id) ->
    trees = trees.filter (t) -> t.id != t_id
    writeTo trees$, trees
addTree = (t) ->
    t.id = ++tree_id
    trees.push t
    writeTo trees$, trees

# Tree adder
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
    page: routes.page$
    q: inputs.q$
    results: results$
    loading: search$.awaiting(results$)
    trees: trees$
    adder: adder$
    tweets: tweets$
    tweets_waiting: Kefir.constant(true).awaiting(tweets$)
    tweets_going: inputs.tweets_going$
    tweets_media: inputs.tweets_media$
    tweets_watching: inputs.tweets_watching$
    word_count: word_count$
    selected_keywords: selected_keywords$

# Components
# ------------------------------------------------------------------------------

App = (app) ->
    h '#app', [
        Nav app
        switch app.page
            when 'persons' then PersonsPage app
            when 'trees' then TreesPage app
            when 'tweets' then TweetsPage app
    ]

Nav = (app) ->
    links = ['persons', 'trees', 'tweets']
    h '#nav', links.map (l) ->
        NavLink l, app

NavLink = (name, app) ->
    elName = 'a'
    if app.page == name
        elName += '.selected'
    h elName, {href: '#' + name}, name

PersonsPage = (app) ->
    h 'div', [
        h 'h1', 'Persons'
        Input inputs.q$, app.q
        h 'strong',
            if app.loading
                'Loading...'
            else if app.results?
                app.results.length + ' results'
            else 'Search for names'
        h 'ul', app.results?.map Result
    ]

TreesPage = (app) ->
    h 'div', [
        h 'h1', 'Trees'
        h 'ul', app.trees?.map Tree
        Adder(app.adder)
    ]

reversed = (a) ->
    a2 = Array.prototype.slice.call(a)
    a2.reverse()
    a2

noTweetsGoing = -> writeTo inputs.tweets_going$, false
yesTweetsGoing = -> writeTo inputs.tweets_going$, true
noTweetsMedia = -> writeTo inputs.tweets_media$, false
yesTweetsMedia = -> writeTo inputs.tweets_media$, true
noTweetsWatching = -> writeTo inputs.tweets_watching$, false
yesTweetsWatching = -> writeTo inputs.tweets_watching$, true
TweetsPage = (app) ->
    h 'div', [
        h 'h1', 'Tweets'
        if app.tweets_going
            h 'a', {onclick: noTweetsGoing}, 'Stop going'
        else
            h 'a', {onclick: yesTweetsGoing}, 'Start going'
        if app.tweets_media
            h 'a', {onclick: noTweetsMedia}, 'Show all tweets'
        else
            h 'a', {onclick: yesTweetsMedia}, 'Show media only'
        if app.tweets_watching
            h 'a', {onclick: noTweetsWatching}, 'Stop watching'
        else
            h 'a', {onclick: yesTweetsWatching}, 'Start watching'
        if app.tweets_waiting
            h 'em', 'Waiting for tweets...'
        else h 'div', [
            Words(app.word_count, app.selected_keywords)
            h '#tweets', reversed(app.tweets).map Tweet
        ]
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

Tweet = (tweet) ->
    h 'div.tweet#'+tweet.id, [
        h 'strong', tweet.user.screen_name
        h 'p', tweet.text
        if tweet.entities.media?
            h 'img', src: tweet.entities.media[0].media_url
    ]

Words = (word_count, selected_keywords) ->
    ps = sorted_pairs(word_count)
    rel = ps.length * 0.005
    h 'div#words', ps.filter(([w,c]) -> c > rel).map (p) ->
        Word p, selected_keywords

Word = ([w, c], selected_keywords) ->
    s = h 'span', [w, h('span.count', "#{c}")]
    if w in selected_keywords
        s = h 'strong', s
        onclick = -> unselectKeyword w
    else
        onclick = -> selectKeyword w
    h 'li', {onclick}, s

# Going
# ------------------------------------------------------------------------------

render App, app$.debounce(10), document.body

writeTo trees$, trees
writeTo selected_keywords$, []
writeTo inputs.tweets_going$, true
writeTo inputs.tweets_media$, false
writeTo inputs.tweets_watching$, true

