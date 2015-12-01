class ExampleController < ApplicationController
  include StatefulController

  class ExampleState < StatefulController::State
    attr_accessor :clean, :tired, :nights
    def initialize
      @clean = true
      @tired = false
      @nights = 1
    end
  end

  # states are 'views' and transitions are 'actions'
  aasm do 
    state :sleeping, initial: true
    state :running
    state :cleaning
    state :finishing
    
    event :run do
      transitions from: :sleeping, to: :running
    end

    event :clean, unless: :clean? do 
      transitions from: :running, to: :cleaning
    end

    event :sleep, unless: :finished? do 
      transitions from: [:running, :cleaning], to: :sleeping
    end

    event :finish, if: :finished? do 
      transitions to: :finishing
    end
  end

  def run
    Rails.logger.debug("event run")
    state.clean = false
    state.tired = true
  end

  def clean
    Rails.logger.debug("event clean")
    state.clean = true
  end

  def sleep
    Rails.logger.debug("event sleep")
    state.tired = false
    state.nights += 1
  end

  def finish
  end

  private

  def clean?
    state.clean
  end
  def tired?
    state.tired
  end
  def finished?
    state.nights >= 2
  end


  # load state however you want...
  def load_state
    session[:state] || ExampleState.new
  end

  def save_state(s)
    session[:state] = s
  end


end
