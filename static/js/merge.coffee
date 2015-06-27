kefir = require 'kefir'

merge = (obs...) ->
    o = {}
    for ob in obs
        for k, v of ob
            o[k] = v
    o

merged = (so, s0={}) ->
    ss = []
    for k, s of so
        do (k) ->
            sm = kefir.constant(s0[k]).concat(s).map (v) ->
                o = {}; o[k]=v; o
            ss.push sm
    kefir.combine ss, merge

module.exports = merged

