require 'stateful_controller/version'
require 'active_support/concern'
require 'aasm'
require 'stateful_controller/extend_aasm'
require 'ostruct'

require 'stateful_controller/railtie' if defined?(Rails)


# StatefulController acts as a hybrid of a Rails controller and a state machine in order to 
# more easily control user flows that may have multiple conditional outputs depending on prior inputs 
# (for example, marketing surveys, tax forms, questionaires, registrations, etc.)
module StatefulController
  extend ActiveSupport::Concern

  # subclass this class to store your own custom state in.
  class State
    # :current_state - the current state of the state machine.
    attr_accessor :current_state
  end

  # things to mixin to the including controller instance
  included do
    include AASM  # make this controller an aasm state machine as well.
    
    # state contains the State object instance and is automatically loaded at the start of an action and saved 
    # at the end of an action.  state can be used within views through the same accessor.
    attr_reader :state
    helper_method :state

    # all actions call load & process before they execute, except for the special action 'start' which places 
    # the user in the initial state with no action (i.e. the start action is not treated as normal event.)
    before_filter :__load_and_process, except: :start
    # all actions call finish after the action to save state.
    after_filter :__finish
    
    # this section removes the event methods that aasm normally adds to the including object
    # so that StatefulController actions can act more like Rails actions instead of firing aasm events.
    class << self
      alias_method :aasm_orig, :aasm

      @__sm_loaded = false
      @__wrapping_method = false

      # note: the assm block must appear before the controller actions.
      def aasm(*args, &block)
        unless args[0].is_a?(Symbol) || args[0].is_a?(String)
          options = args[0] || {}
          args[0] = options.merge(whiny_transitions: false)
        end

        # first process the state machine DSL normally
        ret = aasm_orig(*args, &block)  
        if block
          # then this is a DSL call, so remove the event methods it normally makes on the the object.
          methods_to_remove = aasm.events.map(&:name)
          methods_to_remove.each {|method|
            remove_method(method)            
          }
        end
        @__sm_loaded = true
        ret
      end

      # here we want to prevent events(actions) from being called if the event didn't fire successfully.
      def method_added(method_name)
        return unless @__sm_loaded && !@__wrapping_method
        event_methods = aasm.events.map(&:name)
        if event_methods.include?(method_name)
          @__wrapping_method = true
          wrapped_method = "_#{method_name}".to_sym
          alias_method(wrapped_method,method_name)
          define_method(method_name) {
            if event_fired?
              __debug("calling: #{method_name}")
              self.send(wrapped_method) 
            end
          }
          @__wrapping_method = false
        end
      end

      # before_views allow you to setup state for the view they specify.  
      # NOTE: This is the only place you should mutate state in a StatefulController. 
      def before_view(view_name, &block)
        raise ArgumentError, "aasm must be defined prior to calling before_view" unless @__sm_loaded
        view_names = aasm.states.map(&:name)
        raise ArgumentError, "#{view_name} is not defined in the aasm block as either a view or a state." unless view_names.include?(view_name)
        define_method(view_name, &block)
      end

    end
  end

  # 'next' is a special action that goes to the (first) next available transition according to the state machine.
  def next
    # this may rely on events having exactly one transition... otherwise, we may need an argument? (TBD) 
    next_events = aasm.events(permitted: true).map(&:name)
    __debug("choosing first from possible next events: #{next_events.inspect}")
    next_event = next_events.first
    __process(next_event)  # next does it's own call to __process because it has to lookup permitted events.
    self.send(next_event)
  end

  # 'start' is a special action that clears state and sets the state machine back to the initial state.
  def start
    save_state(nil)
    __load
  end

  protected

  # can be used by actions to determine whether the event fired correctly according to the state machine 
  # (i.e. whether the action matches the current_event)
  # see also, aasm(whiny_transitions: false)
  def event_fired?
    @__fired_event
  end

  def state_changed?
    state.current_state != aasm.current_state
  end

  # StatefulController redefines default_render: instead of rendering a view name that matches the action name, 
  # instead we render a view name that matches the current aasm state name according to the execution of the 
  # state machine so far.
  def default_render(*args)
    __debug("rendering: #{aasm.current_state}")
    render aasm.current_state
  end

  # before filter for setup
  def __load_and_process
    __load
    event = params[:action].to_sym  # rails action should always be something convertible to a symbol
    return if event == :next  # next is a special action, don't try to send the event.
    __process(event)
  end

  def __load
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
    # before we run the state machine or the guards, we need to run the pre-view logic for the current state.
    if self.methods.include?(aasm.current_state)
      __debug("before_view: #{aasm.current_state}")
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
    @__fired_event = aasm_fire_event(:default, event, {persist: false}, [])
    unless event_fired?
      __debug("guards prevented: #{event}")
    end

    # after we've fired the event we also want to run the pre-view for the new current state, but only if it changed from the recorded state.
    if state_changed? && self.methods.include?(aasm.current_state)
      __debug("before_view: #{aasm.current_state}")
      self.send(aasm.current_state)
    end
  end

  # an after_filter that checks to see if the recorded state has changed from the aasm current state.  If it has, then the aasm current state
  # is set in the State object and a save_state message is sent to the implementing controller. 
  def __finish
    if state_changed?
      state.current_state = aasm.current_state
      save_state(state)
      __debug("saved state: #{state.inspect}")
    end
  end

  # load_state is implemented in the controller that includes StatefulController.  The reason this method is deferred is so 
  # that the developer can decide how to persist the state (i.e. use ActiveRecord, Rails' Session, or some other method.)
  # @returns state - an instance of the State or subclass.
  def load_state
    raise NotImplementedError, "Controllers that include StatefulController should define the load_state() method."
  end

  # save_state is implemented in the controller that includes StatefulController.  The reason this method is deferred is so 
  # that the developer can decide how to persist the state (i.e. use ActiveRecord, Rails' Session, or some other method.)
  def save_state(state)
    raise NotImplementedError, "Controllers that include StatefulController should define the save_state(state) method."
  end    

  # internal debugging only!
  def __debug(msg)
    Rails.logger.debug("DEBUG [StatefulController] #{msg}")
  end

end
