class MyController < ActionController::Base
  include StatefulController

  # states are 'views' and transitions are 'actions'
  aasm do 
    state :sleeping, initial: true
    state :running
    state :cleaning
  
    event :run do
      transitions from: :sleeping, to: :running
    end

    event :clean do 
      transitions from: :running, to: :cleaning
    end

    event :sleep do 
      transitions from: [:running, :cleaning], to: :sleeping
    end
  end

  # actions 
  def run
  end

  def clean
  end

  def sleep
  end

  def load_state
    StatefulController::State.new
  end

  def save_state(state)
  end
end
