require 'test_helper'

class SamuraiTest < Test::Unit::TestCase
  def setup
    @gateway = SamuraiGateway.new(
              :merchant_key => "MERCHANT KEY", 
              :merchant_password => "MERCHANT_PASSWORD", 
              :processor_token => "PROCESSOR_TOKEN"
               )


    @sucessful_credit_card = credit_card
    @sucessful_payment_method_token = generate_successful_token
    
    @amount = 100
    
    @options = { 
       :billing_reference =>   "billing_reference",
       :customer_reference =>  "customer_reference",
       :custom => "custom",
       :descriptor => "descriptor"
    }
    
    
  end
  
  
  def test_successful_purchase_with_payment_method_token    
    result = Samurai::Processor.expects(:purchase).
              with(@sucessful_payment_method_token, @amount,@options ).
              returns(successful_purchase_response)
    
    
    response = @gateway.purchase(@amount, @sucessful_payment_method_token, @options)
    assert_instance_of Samurai::Transaction, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    
      payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
      processor_response = Samurai::ProcessorResponse.new(:avs_result_code => "Y")
      transaction = Samurai::Transaction.new(:reference_id => "reference_id",
                  :transaction_token => "transaction_token",
                  :payment_method => payment_method,
                  :processor_response => processor_response
                  )
  end
  
  # Place raw failed response from gateway here
  def failed_purcahse_response
  end
end
