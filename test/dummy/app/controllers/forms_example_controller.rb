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
  end
  def submit
    if action_permitted?
      puts "submit allowed!"
    end
  end
  def done
  end

  protected

  # pre-views: these methods have the same name as views (states) and will be called 
  # before displaying the corresponding view.  This allows the StatefulController to 
  # setup the controller state necesssary for a view no matter what event triggers it.

  def what_is_your_favorite_day
    @days = Date::DAYNAMES.each_with_index.map{|d,i| [d,i]}
    @form = InformationForm.new(state)
  end

  def finish
    @day = Date::DAYNAMES[DateTime.now.wday]
  end

  private
  

  # ------------- guards -------------

  def valid?
    return false if @form.nil?
    valid = @form.validate(params['information'])
    @form.sync if valid  # sync done during guard so that other guard favorite can run, but maybe weird dep order here. :(
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
