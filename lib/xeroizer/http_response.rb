module Xeroizer
  class BadResponse < XeroizerError; end

  class ResponseFailure
    def initialize(response, request_body, url)
      @response = response
      @request_body = request_body
      @url = url
    end

    def raise_error!
      begin
        error_details = JSON.parse(response.plain_body)
        case response.code.to_i
        when 401
          description  = error_details["detail"]
          raise OAuth::TokenExpired.new(description) if description.include?("TokenExpired")
          raise OAuth::TokenInvalid.new(description)
        when 403
          raise OAuth::InvalidTenantId.new("Invalid or missing Xero-tenant-id header")
        else
          raise Error.new("we shouldn't get here with our test suite")
        end
      rescue JSON::ParserError
        case response.code.to_i
        when 400
          raise_bad_request!
        when 401
          AuthFailure.new(response.plain_body).raise_error
        when 403
          AuthFailure.new(response.plain_body).raise_error
        when 404
          raise_not_found!
        when 503
          AuthFailure.new(response.plain_body).raise_error
        else
          raise_unknown_response_error!
        end
      end
    end

    private

    attr_reader :request_body, :response, :url

    def raise_bad_request!

      raw_response = response.plain_body

      # XeroGenericApplication API Exceptions *claim* to be UTF-16 encoded, but fail REXML/Iconv parsing...
      # So let's ignore that :)
      raw_response.gsub! '<?xml version="1.0" encoding="utf-16"?>', ''

      # doc = REXML::Document.new(raw_response, :ignore_whitespace_nodes => :all)
      doc = Nokogiri::XML(raw_response)

      if doc && doc.root && (doc.root.name == "ApiException" || doc.root.name == 'Response')

        raise ApiException.new(doc.root.xpath("Type").text,
          doc.root.xpath("Message").text,
          raw_response,
          doc,
          request_body)

      else
        raise Xeroizer::BadResponse.new("Unparseable 400 Response: #{raw_response}")
      end
    end

    def raise_not_found!
      case url
      when /Invoices/ then raise InvoiceNotFoundError.new("Invoice not found in Xero.")
      when /CreditNotes/ then raise CreditNoteNotFoundError.new("Credit Note not found in Xero.")
      else raise ObjectNotFound.new(url)
      end
    end

    def raise_unknown_response_error!
      raise Xeroizer::BadResponse.new("Unknown response code: #{response.code.to_i}")
    end
  end

  class AuthFailure
    def initialize(body)
      @body = body
    end

    def raise_error
      description, problem = parse

      # see http://oauth.pbworks.com/ProblemReporting
      # In addition to token_expired and token_rejected, Xero also returns
      # 'rate limit exceeded' when more than 60 requests have been made in
      # a second.
      if problem
        case problem
        when "token_expired"                then raise OAuth::TokenExpired.new(description)
        when "token_rejected"               then raise OAuth::TokenInvalid.new(description)
        when "rate limit exceeded"          then raise OAuth::RateLimitExceeded.new(description)
        when "consumer_key_unknown"         then raise OAuth::ConsumerKeyUnknown.new(description)
        when "nonce_used"                   then raise OAuth::NonceUsed.new(description)
        when "organisation offline"         then raise OAuth::OrganisationOffline.new(description)
        else raise OAuth::UnknownError.new(problem + ':' + description)
        end
      else
        raise OAuth::UnknownError.new("Xero API may be down or the way OAuth errors are provided by Xero may have changed.")
      end
    end

    private

    attr_reader :body

    def parse
      error_details = CGI.parse(body)
      description   = error_details["oauth_problem_advice"].first
      problem = error_details["oauth_problem"].first
      [description, problem]
    end
  end

  class HttpResponse
    def self.from_response(response, request_body, url)
      new(response, request_body, url)
    end

    def initialize(response, request_body, url)
      @response = response
      @request_body = request_body
      @url = url
    end

    def body
      response_code = response.code.to_i
      return nil if response_code == 204
      ResponseFailure.new(response, request_body, url).raise_error! unless response.code.to_i == 200
      response.plain_body
    end

    private

    attr_reader :request_body, :response, :url
  end
end

