class FormsExampleController < ApplicationController
  include StatefulController

  class FormsExampleState < StatefulController::State
    attr_accessor 
    def initialize
    end
  end

  # states are 'views' and event transitions are 'actions'
  aasm do 
  end


  # ----------- controller actions --------------



  private

  # ------------- guards -------------



  # ------------- load/save state -------------

  # load state however you want...
  def load_state
    session[:state] || FormsExampleState.new
  end

  def save_state(s)
    session[:state] = s
  end

end
