require 'rubygems'
require 'sinatra'
require 'sinatra/test/unit'
require 'app'

class AppTest < Test::Unit::TestCase
  def test_default
    get_it '/'
    assert_equal 200, @response.status
  end  
end