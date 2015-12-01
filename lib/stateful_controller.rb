require 'stateful_controller/version'
require 'active_support/concern'
require 'aasm'
require 'ostruct'

module StatefulController
  extend ActiveSupport::Concern

  class State
    attr_accessor :current_state
  end

  included do
    include AASM
    attr_reader :state
    helper_method :state
    before_filter :__load_and_process, except: :start
    after_filter :__finish
  end

  # StatefulController always defines a special action called 'next' that goes to the next available transition.
  def next
    # this may rely on events having exactly one transition... otherwise, we may need an argument? (TBD) 
    next_events = aasm.events(permitted: true).map(&:name)
    __debug("choosing first from next events: #{next_events.inspect}")
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
    @state = load_state
    __debug("load_state returned #{@state.inspect}")
    raise ArgumentError, "load_state() must return a StatefulController::State or subclass." unless @state.kind_of?(State)

    # allow the StatefulController to retain it's current state across requests (since controller instances are created per request in Rails)
    if state.current_state.nil?
      state.current_state = aasm.current_state  # if load_state didn't recover a current_state, then use the aasm initial.
    else
      aasm.current_state = state.current_state  # otherwise, set the aasm.current_state to the loaded current_state.
    end
  end

  def __process(event)
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
  end

  def __finish
    state.current_state = aasm.current_state
    __debug("calling save_state with #{state.inspect}")
    save_state(state)
  end

  def load_state
    raise NotImplementedError, "Controllers that include StatefulController should define the load_state() method."
  end

  def save_state
    raise NotImplementedError, "Controllers that include StatefulController should define the save_state() method."
  end    

  def __debug(msg)
    Rails.logger.debug("DEBUG [StatefulController]: #{msg}")
  end

end
