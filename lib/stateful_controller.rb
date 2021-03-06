require 'stateful_controller/version'
require 'active_support/concern'
require 'aasm'
require 'stateful_controller/extend_aasm'
require 'ostruct'
require 'forwardable'
require 'hashie'
require 'active_model/conversion'
require 'stateful_controller/railtie' if defined?(Rails)


# StatefulController acts as a hybrid of a Rails controller and a state machine in order to 
# more easily control user flows that may have multiple conditional outputs depending on prior inputs 
# (for example, marketing surveys, tax forms, questionaires, registrations, etc.)
module StatefulController
  extend ActiveSupport::Concern

  # subclass this class to store your own custom state in.
  class State < Hashie::Mash
    # make this state object support AM conversion.  use case: reform form (backed with state) passed to form_for tag.
    include ActiveModel::Conversion
    # it is up to the implementer of save_state and load_state to directly persist this object, not AM or AR indirectly.
    def persisted?; false; end
  end

  # things to mixin to the including controller instance
  included do
    extend Forwardable  # allow this controller to forward guards to the state object.
    include AASM  # make this controller an aasm state machine as well.
    
    # state contains the State object instance and is automatically loaded at the start of an action and saved 
    # at the end of an action.  state can be used within views through the same accessor.
    attr_reader :state
    helper_method :state

    # in the case where a form validation wants to set http status codes for render, we need a way
    # to store the status for the deferred render.
    attr_accessor :rails_status

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
          # then this is a DSL call, so remove the event methods it normally makes on the the object
          # because we want the user to define their own.  We are doing what these auto methods do manually 
          # under the covers, so we don't need them (see __process).  Also, we don't want users manipulating 
          # events directly.  One event per action is enforced by StatefulController.
          methods_to_remove = aasm.events.map(&:name)
          methods_to_remove.each {|method|
            remove_method(method)            
          }
        end
        @__sm_loaded = true
        ret
      end

      # here we want to prevent events(actions) from being called if the event didn't fire successfully.
      # event methods should also be defined after the aasm block, but we can't raise an ArgumentError here
      # because of chicken & egg scenario: we only want to intercept events, but we can't know what 
      # events were added unless the aasm block was first.  But the aasm block definition will trigger this
      # method during construction, so... leave it alone.
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

      # just a synonym for creating a guard method.  helpful for organization.
      def guard(guard_name, &block)
        define_method(guard_name, &block)
      end

      # guards need to be based on state, so might as well make it official.
      # with Hashie::Mash, these can be pass-thrus.
      def state_guard(guard_name)
        def_delegator(:@state, guard_name)
      end

    end # class<self    
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
  # the optional :initial part of the route allows the state machine to start in arbitrary parts of the 
  # defined state machine, which can be useful for complex flows.
  def start
    save_state(nil)
    __load
    if params[:initial].present?
      # only set the state, don't process because this isn't an event.
      aasm.current_state = params[:initial].to_sym
    end
    # before view should always be run, even on start if present.
    if self.methods.include?(aasm.current_state)
      __debug("before_view: #{aasm.current_state}")
      self.send(aasm.current_state)
    end
  end

  protected

  # can be used by actions to determine whether the event fired correctly according to the state machine 
  # (i.e. whether the action matches the current_event)
  # see also, aasm(whiny_transitions: false)
  def event_fired?
    @__fired_event
  end

  # can be used by actions to abort the current transistion (i.e. if an action failed)
  # state machine will not advance if aborted.
  def abort
    __debug("aborting #{aasm.current_event}")
    @__abort = true
  end

  def state_changed?
    state.current_state != aasm.current_state
  end

  def aborted?
    @__abort == true
  end

  # StatefulController redefines default_render: instead of rendering a view name that matches the action name, 
  # instead we render a view name that matches the current aasm state name according to the execution of the 
  # state machine so far.
  def default_render(*args)
    if aborted?
      __debug("aborted! rendering: #{state.current_state} with status #{rails_status.inspect}")
      render state.current_state, status: rails_status
    else
      __debug("rendering: #{aasm.current_state} with status #{rails_status.inspect}")
      render aasm.current_state, status: rails_status
    end
  end

  # before filter for setup
  def __load_and_process
    # in the case where you need to start from a sub-action in the middle of a sm, you also need to force
    # the sm to be cleared before any processing, otherwise you could get stuck.  This adds a optional param to any action route
    # allowing the state machine to be reset right before the action.
    if params[:clear]
      __debug("clearing state with save_state(nil)")
      save_state(nil)
    end
    
    __load
    event = params[:action].to_sym  # rails action should always be something convertible to a symbol
    return if event == :next  # next is a special action, don't try to send the event.
    __process(event)
  end

  def __load
    @state = load_state
    pp_state = PP.pp(@state.sort.to_h, '')
    __debug("loaded state: #{pp_state}")
    raise ArgumentError, "load_state() must return a StatefulController::State or subclass." unless @state.kind_of?(State)

    # allow the StatefulController to retain it's current state across requests (since controller instances are created per request in Rails)
    if state.current_state.nil?
      state.current_state = aasm.current_state  # if load_state didn't recover a current_state, then use the aasm initial.
    else
      aasm.current_state = state.current_state  # otherwise, set the aasm.current_state to the loaded current_state.
    end
  end

  def __process(event)
    # store state in case action calls abort.
    previous_state = aasm.current_state
    @__abort = false

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

    # if abort was called within a before_view, we need to stop the event from firing normally.
    #  i.e. the guards passed but the flow was still aborted, say for conditional validation.
    unless aborted?
      # also, aasm supports arguments for events, but because StatefulController models Rails controller actions, no arguments or blocks are supported.
      # original line:  aasm_fire_event(:#{@name}, :#{name}, {:persist => false}, *args, &block)
      @__fired_event = aasm_fire_event(:default, event, {persist: false}, [])
      unless event_fired?
        pp_state = PP.pp(state.sort.to_h, '')
        __debug("guards prevented: #{event}, using state: #{pp_state}")
      end
    else 
      @__fired_event = false
      __debug("aborted during before_view: #{aasm.current_state}")
    end
    

    # after we've fired the event we also want to run the pre-view for the new current state, but only if it changed from the recorded state.
    if state_changed? && self.methods.include?(aasm.current_state)
      # if a before_view exists then execute it.
      if self.methods.include?(aasm.current_state)
        __debug("before_view: #{aasm.current_state}")
        self.send(aasm.current_state)
      end      
    end
  end

  # an after_filter that checks to see if the recorded state has changed from the aasm current state.  If it has, then the aasm current state
  # is set in the State object and a save_state message is sent to the implementing controller. 
  def __finish
    if state_changed?

      # if the action(event) aborted, then we need to reset to the previous state.
      if aborted?
        __debug("aborted transition, discarding state changes.")
      else
        state.current_state = aasm.current_state
        save_state(state)
        pp_state = PP.pp(state.sort.to_h, '')
        __debug("saved state: #{pp_state}")
      end

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
