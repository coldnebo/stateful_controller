

## 0.2.0

* add 'clear' param to allow paths to clear the underlying state and start fresh.  e.g.

    link_to('Click!', click_path(clear: true))

  assuming click_path maps to an action in a StatefulController, clear: true on the link 
  would automatically set the current state to nil allowing a new state object to be created for that
  request.

