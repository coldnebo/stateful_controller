class FormsExampleController < ApplicationController
  include StatefulController

  # class FormsExampleState < StatefulController::State
  #   attr_accessor :name, :favorite_day, :valid
  #   def initialize
  #     @valid = false
  #   end
  # end

  aasm do 
    view :welcome, initial: true
    view :what_is_your_favorite_day
    view :favorite_day
    view :goodbye

    action :ask do
      transitions from: :welcome, to: :what_is_your_favorite_day      
    end

    action :submit, if: :valid? do
      transitions from: :what_is_your_favorite_day, to: :favorite_day, if: :favorite?
      transitions from: :what_is_your_favorite_day, to: :goodbye
    end

    action :finish do
      transitions to: :goodbye
    end

  end


  # ----------- controller actions --------------
  # actions (events)
  def ask
  end
  def submit
    Rails.logger.info "submitted!!"
  end
  def finish
  end


  protected

  # before_view: these blocks will be called 
  # before displaying the corresponding view.  This allows the StatefulController to 
  # setup the controller state necesssary for a view no matter what event triggers it.

  # note that on an event transition, two before_views may be called: the first is the state 
  # before the transition and the second is the state after the transition.

  before_view :what_is_your_favorite_day do 
    @days = Date::DAYNAMES.each_with_index.map{|d,i| [d,i]}
    @form = InformationForm.new(state)
    # in case of repost or validation scenario... this is like traditional rails repost logic.
    if params.has_key?(:information) && @form.validate(params[:information])
      @form.sync
      # note that state is set on the preview, but won't be saved unless the state transition actually changes 
      # i.e. action_permitted?
      state.valid = true
    end
  end

  before_view :goodbye do
    @day = Date::DAYNAMES[DateTime.now.wday]
  end

  private
  

  # ------------- guards -------------

  # guards should always be expressed in terms of state because they can run anywhere anytime.
  # (i.e. before_views can be tied to view forms, but guards should be based on a longer lifetime.)
  state_guard :valid?

  # is today your favorite day
  guard :favorite? do
    DateTime.now.wday == state.favorite_day.to_i
  end


  # ------------- load/save state -------------

  # load state however you want...
  def load_state
    state = session[:state] || State.new
  end

  def save_state(s)
    session[:state] = s
  end

end
