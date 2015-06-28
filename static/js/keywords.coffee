stop_words = '- rt a am an i we us is are the to too that in on and of which what where has it be vs for with like can have these those them they there'.split(' ')

notStop = (w) ->
    w.length and w not in stop_words
keyword = (w) ->
    w.replace /[^a-z]/g, ''
keywords = (s) ->
    s.toLowerCase().split(' ').map(keyword).filter(notStop)

module.exports = keywords
