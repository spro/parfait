h = require 'virtual-dom/h'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'

# Loop
# ------------------------------------------------------------------------------

render = (component, state$, el) ->

    # Set up root node
    tree = h('div')
    rootNode = createElement(tree)
    el.appendChild rootNode

    # Render new app state
    renderRoot = (state) ->
        newTree = component(state)
        patches = diff(tree, newTree)
        rootNode = patch(rootNode, patches)
        tree = newTree
        return

    # Render on every state change
    state$.onValue renderRoot

module.exports = render
