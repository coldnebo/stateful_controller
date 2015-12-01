require 'test_helper'
require 'action_controller'

class StatefulControllerTest < Minitest::Test
  
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
  end


  def test_that_it_has_a_version_number
    refute_nil ::StatefulController::VERSION
  end


  def test_it_has_its_own_state
    instance = MyController.new
    assert instance.state.nil?
  end
  
end
