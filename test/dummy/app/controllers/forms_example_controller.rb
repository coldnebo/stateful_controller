class FormsExampleController < ApplicationController
  include StatefulController

  class FormsExampleState < StatefulController::State
    attr_accessor :name, :favorite_day
    def initialize
    end
  end

  aasm(whiny_transitions: false) do 
    view :welcome, initial: true
    view :what_is_your_favorite_day
    view :favorite_day
    view :finish

    action :ask do
      transitions from: :welcome, to: :what_is_your_favorite_day      
    end

    action :submit, if: :valid? do
      transitions from: :what_is_your_favorite_day, to: :favorite_day, if: :favorite?
      transitions from: :what_is_your_favorite_day, to: :finish
    end

    action :done do
      transitions to: :finish
    end

  end


  # ----------- controller actions --------------
  # actions (events)
  def ask
    __debug("running ask")
  end
  def submit
    __debug("running submit")
    if action_valid?
      __debug("submitted!")      
    end
  end
  def done
    __debug("running done")
  end

  protected

  def what_is_your_favorite_day
    __debug("run view prep")
    @days = Date::DAYNAMES.each_with_index.map{|d,i| [d,i]}
    @form = InformationForm.new(state)
  end

  private
  

  # ------------- guards -------------

  def valid?
    __debug("run guard valid?")
    valid = @form.validate(params['information'])
    @form.sync if valid
    valid
  end
  # is today your favorite day?
  def favorite?
    DateTime.now.wday == state.favorite_day.to_i
  end


  # ------------- load/save state -------------

  # load state however you want...
  def load_state
    session[:state] || FormsExampleState.new
  end

  def save_state(s)
    session[:state] = s
  end

end
