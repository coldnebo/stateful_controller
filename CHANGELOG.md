
## 0.3.0

* add rails_status, which is a method for returning http status codes from the deferred render.
* add abort() which may be called any time during an action or before_view to stop the current transition.
* before_views are now optional (i.e. they don't have to exist, which may be useful for views without setup)
* pp state during normal and exception cases for easier debugging.


## 0.2.0

* add 'clear' param to allow paths to clear the underlying state and start fresh.  e.g.

    link_to('Click!', click_path(clear: true))

  assuming click_path maps to an action in a StatefulController, clear: true on the link 
  would automatically set the current state to nil allowing a new state object to be created for that
  request.

