require 'test_helper'

class RemoteSamuraiTest < Test::Unit::TestCase
  

  def setup
    @gateway = SamuraiGateway.new(fixtures(:samurai))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4242424242424242')
    
    @options = { 
       :billing_reference =>   "billing_reference",
       :customer_reference =>  "customer_reference",
       :custom => "custom",
       :descriptor => "descriptor",
       
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Processor transaction declined', response.message
  end

  def test_successful_auth_and_capture
    amount = @amount
    assert authorize = @gateway.authorize(amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'OK', authorize.message
    assert capture = @gateway.capture(amount, authorize.authorization, @options)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_invalid_login
    gateway = SamuraiGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  end
end
