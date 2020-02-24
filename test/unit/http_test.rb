require 'unit_test_helper'

class HttpTest < UnitTestCase
  include TestHelper

  setup do
    @uri = "https://api.xero.com/path"
  end

  context "default_headers" do
    setup do
      @headers = { "User-Agent" => "Xeroizer/2.15.5" }
      @application = Xeroizer::PublicApplication.new(CONSUMER_KEY, CONSUMER_SECRET, :default_headers => @headers)
    end

    should "recognize default_headers" do
      # Xeroizer::OAuth.any_instance.expects(:get).with("/test", has_entry(@headers)).returns(stub(:plain_body => "", :code => "200"))
      # @application.http_get(@application.client, "http://example.com/test")
    end
  end

  context "errors" do
    setup do
      @application = Xeroizer::PublicApplication.new(CONSUMER_KEY, CONSUMER_SECRET)
    end

    context "400" do
      setup do
        status_code = 400
        @body = get_file_as_string("credit_note_not_found_error.xml")
        stub_request(:get, @uri).to_return(status: status_code, body: @body)
      end

      should "raise an ApiException" do
        error = assert_raises(Xeroizer::ApiException) { @application.http_get(@application.client, @uri) }
        assert_equal ":  \n Generated by the following XML: \n #{@body}", error.message
      end
    end

    context "401" do
      setup do
        @status_code = 401
      end

      context "token_expired" do
        setup do
          body = get_file_as_string("token_expired")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::TokenExpired" do
          error = assert_raises(Xeroizer::OAuth::TokenExpired) { @application.http_get(@application.client, @uri) }
          assert_equal "Unexpected token", error.message
        end
      end

      context "token_rejected" do
        setup do
          body = "oauth_problem_advice=some advice&oauth_problem=token_rejected"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::TokenInvalid" do
          error = assert_raises(Xeroizer::OAuth::TokenInvalid) { @application.http_get(@application.client, @uri) }
          assert_equal "some advice", error.message
        end
      end

      context "rate limit exceeded" do
        setup do
          body = get_file_as_string("rate_limit_exceeded")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::RateLimitExceeded" do
          error = assert_raises(Xeroizer::OAuth::RateLimitExceeded) { @application.http_get(@application.client, @uri) }
          assert_equal "please wait before retrying the xero api\n", error.message
        end
      end

      context "consumer_key_unknown" do
        setup do
          body = "oauth_problem_advice=some more advice&oauth_problem=consumer_key_unknown"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::ConsumerKeyUnknown" do
          error = assert_raises(Xeroizer::OAuth::ConsumerKeyUnknown) { @application.http_get(@application.client, @uri) }
          assert_equal "some more advice", error.message
        end
      end

      context "nonce_used" do
        setup do
          body = get_file_as_string("nonce_used")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::NonceUsed" do
          error = assert_raises(Xeroizer::OAuth::NonceUsed) { @application.http_get(@application.client, @uri) }
          assert_equal "The nonce value \"potatocakes\" has already been used ", error.message
        end
      end

      context "organisation offline" do
        setup do
          body = "oauth_problem_advice=organisational advice&oauth_problem=organisation offline"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::OrganisationOffline" do
          error = assert_raises(Xeroizer::OAuth::OrganisationOffline) { @application.http_get(@application.client, @uri) }
          assert_equal "organisational advice", error.message
        end
      end

      context "unknown error" do
        setup do
          body = "oauth_problem_advice=unknown advice&oauth_problem=unknown error"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::UnknownError" do
          error = assert_raises(Xeroizer::OAuth::UnknownError) { @application.http_get(@application.client, @uri) }
          assert_equal "unknown error:unknown advice", error.message
        end
      end
    end

    context "404" do
      setup do
        @status_code = 404
      end

      context "invoices" do
        setup do
          @uri = "https://api.xero.com/Invoices"
          body = get_file_as_string("invoice_not_found_error.xml")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an InvoiceNotFoundError" do
          error = assert_raises(Xeroizer::InvoiceNotFoundError) { @application.http_get(@application.client, @uri) }
          assert_equal "Invoice not found in Xero.", error.message
        end
      end

      context "credit notes" do
        setup do
          @uri = "https://api.xero.com/CreditNotes"
          body = get_file_as_string("credit_note_not_found_error.xml")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an CreditNoteNotFoundError" do
          error = assert_raises(Xeroizer::CreditNoteNotFoundError) { @application.http_get(@application.client, @uri) }
          assert_equal "Credit Note not found in Xero.", error.message
        end
      end

      context "anything else" do
        setup do
          stub_request(:get, @uri).to_return(status: @status_code, body: "body")
        end

        should "raise an ObjectNotFound" do
          error = assert_raises(Xeroizer::ObjectNotFound) { @application.http_get(@application.client, @uri) }
          assert_equal "Couldn't find object for API Endpoint #{@uri}", error.message
        end
      end
    end

    context "503" do
      setup do
        @status_code = 503
      end

      context "token_expired" do
        setup do
          body = get_file_as_string("token_expired")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::TokenExpired" do
          error = assert_raises(Xeroizer::OAuth::TokenExpired) { @application.http_get(@application.client, @uri) }
          assert_equal "Unexpected token", error.message
        end
      end

      context "token_rejected" do
        setup do
          body = "oauth_problem_advice=some advice&oauth_problem=token_rejected"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::TokenInvalid" do
          error = assert_raises(Xeroizer::OAuth::TokenInvalid) { @application.http_get(@application.client, @uri) }
          assert_equal "some advice", error.message
        end
      end

      context "rate limit exceeded" do
        setup do
          body = get_file_as_string("rate_limit_exceeded")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::RateLimitExceeded" do
          error = assert_raises(Xeroizer::OAuth::RateLimitExceeded) { @application.http_get(@application.client, @uri) }
          assert_equal "please wait before retrying the xero api\n", error.message
        end
      end

      context "consumer_key_unknown" do
        setup do
          body = "oauth_problem_advice=some more advice&oauth_problem=consumer_key_unknown"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::ConsumerKeyUnknown" do
          error = assert_raises(Xeroizer::OAuth::ConsumerKeyUnknown) { @application.http_get(@application.client, @uri) }
          assert_equal "some more advice", error.message
        end
      end

      context "nonce_used" do
        setup do
          body = get_file_as_string("nonce_used")
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::NonceUsed" do
          error = assert_raises(Xeroizer::OAuth::NonceUsed) { @application.http_get(@application.client, @uri) }
          assert_equal "The nonce value \"potatocakes\" has already been used ", error.message
        end
      end

      context "organisation offline" do
        setup do
          body = "oauth_problem_advice=organisational advice&oauth_problem=organisation offline"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::OrganisationOffline" do
          error = assert_raises(Xeroizer::OAuth::OrganisationOffline) { @application.http_get(@application.client, @uri) }
          assert_equal "organisational advice", error.message
        end
      end

      context "unknown error" do
        setup do
          body = "oauth_problem_advice=unknown advice&oauth_problem=unknown error"
          stub_request(:get, @uri).to_return(status: @status_code, body: body)
        end

        should "raise an OAuth::UnknownError" do
          error = assert_raises(Xeroizer::OAuth::UnknownError) { @application.http_get(@application.client, @uri) }
          assert_equal "unknown error:unknown advice", error.message
        end
      end
    end

    context "other status" do
      setup do
        body = get_file_as_string("token_expired")
        stub_request(:get, @uri).to_return(status: 418, body: body)
      end

      should "raise an BadRespone" do
        error = assert_raises(Xeroizer::BadResponse) { @application.http_get(@application.client, @uri) }
        assert_equal "Unknown response code: 418", error.message
      end

    end
  end
end
