module AASM
  class Base

    # synonyms to adapt the aasm DSL in the context of Rails controller 'views' and 'ations' 
    # instead of aasm 'states' and 'events', but you can use either.

    # synonym view for state
    alias_method :view, :state
    # synonym action for event
    alias_method :action, :event
  end
end