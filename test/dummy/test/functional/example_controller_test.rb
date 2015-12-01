require 'test_helper'

class ExampleControllerTest < ActionController::TestCase
  test "should get run" do
    get :run
    assert_response :success
  end

  test "should get clean" do
    get :clean
    assert_response :success
  end

  test "should get sleep" do
    get :sleep
    assert_response :success
  end

end
