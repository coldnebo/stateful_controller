class ExampleController < ApplicationController
  include StatefulController

  # class ExampleState < StatefulController::State
  #   attr_accessor :clean, :tired, :nights
  #   def initialize
  #     @clean = true
  #     @tired = false
  #     @nights = 1
  #   end
  # end

  # states are 'views' and transitions are 'actions'
  aasm do 
    view :sleeping, initial: true
    view :running
    view :cleaning
    view :finishing
    
    action :run do
      transitions from: :sleeping, to: :running
    end

    action :clean, unless: :clean? do 
      transitions from: :running, to: :cleaning
    end

    action :sleep, unless: :finished? do 
      transitions from: [:running, :cleaning], to: :sleeping
    end

    action :finish, if: :finished? do 
      transitions to: :finishing
    end
  end

  def run
    state.clean = false
    state.tired = true
  end

  def clean
    state.clean = true
  end

  def sleep
    state.tired = false
    state.nights += 1
  end

  def finish
  end

  private

  state_guard :clean? 
  state_guard :tired? 
  guard :finished? do
    state.nights >= 2
  end


  # load state however you want...
  def load_state
    state = session[:state] || State.new
    state.nights = 1 unless state.nights?  # initialization code moved here since Hashie::Mash above. Am I happy with this? Hmm.
    state
  end

  def save_state(s)
    session[:state] = s
  end


end
