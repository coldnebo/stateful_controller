require 'test_helper'
require 'action_controller'


require 'test_controller'


describe StatefulController do

  let(:instance) { MyController.new }
  
  it "has a version number" do
    refute_nil ::StatefulController::VERSION
  end

  it "has its own state" do
    instance.start
    assert instance.state.current_state == :sleeping
  end

  it "fires events" do
    skip
    instance.start
    instance.run
    event_fired = instance.instance_eval{ event_fired? }
  end

end
