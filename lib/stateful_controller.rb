require 'stateful_controller/version'
require 'active_support/concern'
require 'aasm'
require 'stateful_controller/extend_aasm'
require 'ostruct'

require 'stateful_controller/railtie' if defined?(Rails)


module StatefulController
  extend ActiveSupport::Concern

  class State
    attr_accessor :current_state
  end

  included do
    include AASM
    attr_reader :state
    helper_method :state
    before_filter :__load_and_process, except: [:start, :template]
    after_filter :__finish, except: :template
    
    # this section removes the event methods that aasm normally adds to the including object.
    #   # because this object is meant to be a controller, the events (actions) should obey Rails
    #   # behavior, so we remove the methods and manage the state transitions internally.
    class << self
      alias_method :aasm_orig, :aasm

      def aasm(*args, &block)
        ret = aasm_orig(*args, &block)  # first process the state machine DSL normally
        if block
          # then this is a DSL call, so remove the event methods it normally makes on the the object.
          methods_to_remove = aasm.events.map(&:name)
          methods_to_remove.each {|method|
            remove_method(method)
          }
       end
        ret
      end
    end
  end

  # StatefulController always defines a special action called 'next' that goes to the next available transition.
  def next
    # this may rely on events having exactly one transition... otherwise, we may need an argument? (TBD) 
    next_events = aasm.events(permitted: true).map(&:name)
    __debug("choosing first from possible next events: #{next_events.inspect}")
    next_event = next_events.first
    __process(next_event)
    self.send(next_event)
  end

  # SC also has a special action called "start" which clears state and reloads it (defaulting back to the initial state)
  def start
    save_state(nil)
    __load
  end

  protected

  def initialize
    super
  end

  def default_render(*args)
    __debug("default_render current state")
    render aasm.current_state
  end

  # before filter for setup
  def __load_and_process
    __load

    # rails action should always be something convertible to a symbol
    event = params[:action].to_sym

    # next is a special action, don't try to send the event.
    return if event == :next

    __process(event)
  end

  def __load
    __debug("__load")
    @state = load_state
    __debug("loaded state: #{@state.inspect}")
    raise ArgumentError, "load_state() must return a StatefulController::State or subclass." unless @state.kind_of?(State)

    # allow the StatefulController to retain it's current state across requests (since controller instances are created per request in Rails)
    if state.current_state.nil?
      state.current_state = aasm.current_state  # if load_state didn't recover a current_state, then use the aasm initial.
    else
      aasm.current_state = state.current_state  # otherwise, set the aasm.current_state to the loaded current_state.
    end
  end

  def __process(event)
    __debug("__process")
    # before anything else, we want to run the optional view init... this will load any view specific state 
    # before the guards might actually need it.
    # TODO: THIS TURNED INTO A RIPE MESS  -- HOW TO FIX?
    # ONCE BEFORE?
    if self.methods.include?(aasm.current_state)
      self.send(aasm.current_state)
    end

    # manually trigger the event (while we consider the aasm events as "actions", we reserve the methods in the 
    # controller as actual actions instead of aasm event triggering sugar.)
    # adapted from ./lib/aasm/base.rb:85

    # while the aasm gem supports multiple state machines per class, StatefulController always uses only one state machine, the default.
    # so we may substitute :default for @name in the DSL impl:
    # original line:  aasm(:#{@name}).current_event = :#{name}
    aasm.current_event = event

    # also, aasm supports arguments for events, but because StatefulController models Rails controller actions, no arguments or blocks are supported.
    # original line:  aasm_fire_event(:#{@name}, :#{name}, {:persist => false}, *args, &block)
    aasm_fire_event(:default, event, {persist: false}, [])

    # before anything else, we want to run the optional view init... this will load any view specific state 
    # before the guards might actually need it.
    # TODO: THIS TURNED INTO A RIPE MESS  -- HOW TO FIX?
    # ONCE AGAIN AFTER CHANGE?
    if self.methods.include?(aasm.current_state)
      self.send(aasm.current_state)
    end
  end

  def __finish
    state.current_state = aasm.current_state
    save_state(state)
    __debug("saved state: #{state.inspect}")
  end

  def load_state
    raise NotImplementedError, "Controllers that include StatefulController should define the load_state() method."
  end

  def save_state(state)
    raise NotImplementedError, "Controllers that include StatefulController should define the save_state(state) method."
  end    

  def __debug(msg)
    Rails.logger.debug("DEBUG [StatefulController] #{msg}")
  end

end
