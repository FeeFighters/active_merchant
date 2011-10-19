require 'samurai'
rescue LoadError
  raise "Could not load the samurai gem.  Use `gem install samurai` to install it."
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SamuraiGateway < Gateway
      LIVE_URL = 'https://api.samurai.feefighters.com/v1'
      
      self.homepage_url = 'http://samurai.feefighters.com'
      self.display_name = 'Samurai'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
      self.default_currency = 'USD'
      self.money_format = :cents
      
      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        super
      end
      
      def authorize(money, creditcard, options = {})
        purchase(money, creditcard, options.merge(:uncaptured => true))
      end
      
      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_customer(post, options)
        add_customer_data(post, options)
        add_flags(post, options)

        raise ArgumentError.new("Customer or Credit Card required.") if !post[:card] && !post[:customer]

        commit('charges', post)
      end                 
    
      def capture(money, identification, options = {})
        commit("charges/#{CGI.escape(identification)}/capture", {})
      end

      def void(identification, options={})
        commit("charges/#{CGI.escape(identification)}/refund", {})
      end

      def refund(money, identification, options = {})
        post = {}

        post[:amount] = amount(money) if money

        commit("charges/#{CGI.escape(identification)}/refund", post)
      end

      def store(creditcard, options={})
        post = {}
        add_creditcard(post, creditcard, options)
        add_customer_data(post, options)

        if options[:customer]
          commit("customers/#{CGI.escape(options[:customer])}", post)
        else
          commit('customers', post)
        end
      end
      
      private
      
      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money)).downcase
      end
      
      def add_billing_reference(post, options)
        post[:description] = options[:description]
      end

      def add_customer_reference(post, options)
        post[:description] = options[:description]
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:credit_card][:address_1] = address[:address1] if address[:address1]
          post[:credit_card][:address_2] = address[:address2] if address[:address2]
          post[:credit_card][:country] = address[:country] if address[:country]
          post[:credit_card][:zip] = address[:zip] if address[:zip]
          post[:credit_card][:state] = address[:state] if address[:state]
        end
      end

      def add_creditcard(post, creditcard, options)
        if creditcard.respond_to?(:number)
          card = {}
          card[:card_number] = creditcard.number
          card[:expiry_month] = creditcard.month
          card[:expiry_year] = creditcard.year
          card[:cvv] = creditcard.verification_value if creditcard.verification_value?
          card[:name] = creditcard.name if creditcard.name
          post[:card] = card

          add_address(post, options)
        elsif creditcard.kind_of?(String)
          post[:credit_card] = creditcard
        end
      end

      def add_customer(post, options)
        post[:customer] = options[:customer] if options[:customer] && !post[:credit_card]
      end

      def post_data(params)
        params.map do |key, value|
          next if value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def headers
        @@ua ||= XML.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant',
          :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
        })

        {
          "Authorization" => "Basic " + ActiveSupport::Base64.encode64(@merchant_key.to_s + ":" + @merchant_password.to_s ).strip,
          "User-Agent" => "samurai/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "SamuraiAM-Client-User-Agent" => @@ua
        }
      end

      def commit(url, parameters, method=:post)
        raw_response = response = nil
        success = false
        begin
          raw_response = ssl_request(method, LIVE_URL + url, post_data(parameters), headers)
          response = parse(raw_response)
          success = !response.key?("error")
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue XML::ParserError
          xml_error(raw_response)
        end
      end
        

      def xml_error(raw_response)
        msg = 'No valid response received from the Samurai API.  Please contact support if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end
    end
  end
end
      