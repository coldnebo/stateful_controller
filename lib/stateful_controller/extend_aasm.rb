module AASM
  class Base
    alias_method :view, :state
    alias_method :action, :event
  end
end