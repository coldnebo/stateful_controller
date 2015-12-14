require 'simplecov'
SimpleCov.start do 
  add_filter "/test/"
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'stateful_controller'

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/unit'
require 'mocha/mini_test'
require 'pry'

require 'mock_rails'