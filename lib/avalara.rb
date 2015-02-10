require 'avalara/version'
require 'avalara/errors'
require 'avalara/configuration'

require 'avalara/api'

require 'avalara/types'
require 'avalara/request'
require 'avalara/response'
require 'addressable/uri'

module Avalara

  def self.configuration
    @@_configuration ||= Avalara::Configuration.new
    yield @@_configuration if block_given?
    @@_configuration
  end

  def self.configuration=(configuration)
    raise ArgumentError, 'Expected a Avalara::Configuration instance' unless configuration.kind_of?(Configuration)
    @@_configuration = configuration
  end

  def self.configure(&block)
    configuration(&block)
  end

  def self.endpoint
    configuration.endpoint
  end
  def self.endpoint=(endpoint)
    configuration.endpoint = endpoint
  end

  def self.username
    configuration.username
  end
  def self.username=(username)
    configuration.username = username
  end

  def self.password
    configuration.password
  end
  def self.password=(password)
    configuration.password = password
  end

  def self.company_code
    configuration.company_code
  end
  def self.company_code=(company_code)
    configuration.company_code = company_code
  end

  def self.version
    configuration.version
  end
  def self.version=(version)
    configuration.version = version
  end

  def self.geographical_tax(latitude, longitude, sales_amount)
    #raise NotImplementedError
    uri = [endpoint, version, "tax", "#{latitude},#{longitude}", "get"].join("/")

    response = API.get(uri,
                       :headers => API.headers_for('0'),
                       :query => { :saleamount => sales_amount },
                       :basic_auth => authentication
    )
    return case response.code
             when 200..299
               Response::TaxDetail.new(response)
             when 400..599
               raise ApiError.new(Response::TaxDetail.new(response))
             else
               raise ApiError.new(response)
           end

  rescue Timeout::Error
    puts "Timed out"
    raise TimeoutError
  end

  def self.get_tax(invoice)
    uri = [endpoint, version, 'tax', 'get'].join('/')

    response = API.post(uri,
                        :body => invoice.to_json,
                        :headers => API.headers_for(invoice.to_json.length),
                        :basic_auth => authentication
    )

    return case response.code
             when 200..299
               Response::Invoice.new(response)
             when 400..599
               raise ApiError.new(Response::Invoice.new(response))
             else
               raise ApiError.new(response)
           end
  rescue Timeout::Error => e
    raise TimeoutError.new(e)
  rescue ApiError => e
    raise e
  rescue Exception => e
    raise Error.new(e)
  end

  def self.validate_address(address)
    uri = [endpoint, version, 'address', 'validate?'].join('/')

    encodedquery = Addressable::URI.new
    encodedquery.query_values = set_address_params(address)
    uri += encodedquery.query

    response = API.get(uri,
                        :headers => API.headers_for('0'),
                        :basic_auth => authentication
    )

    return case response.code
             when 200..299
               address_match?(address, response["Address"])
               Response::TaxAddress.new(response)
             when 400..599
               raise Error.new(response["Messages"].first["Summary"]) unless response["Messages"].first["Summary"].eql?('Country not supported.')
             else
               raise ApiError.new(response)
           end
  rescue Timeout::Error => e
    raise TimeoutError.new(e)
  rescue ApiError => e
    raise e
  rescue Exception => e
    raise Error.new(e)

  end

  private

  def self.authentication
    { :username => username, :password => password}
  end

  def self.address_match? address, response_address
    errors = []
    state = ((address.state && address.state.abbr) || (address.state_name || ''))
    response_address.each { |k,v| v.downcase! }
    errors << "Invalid City : #{response_address['City']}" unless response_address["City"].eql?(address.city.downcase)
    errors << "Invalid State : #{response_address['Region']}"  unless  response_address["Region"].eql?(state.downcase)
    errors << "Invalid PostalCode : #{response_address['PostalCode']}" unless response_address["PostalCode"].split('-').first.eql?(address.zipcode.downcase)
    errors << "Invalid Country" unless  response_address["Country"].eql?(address.country.iso.downcase)
    raise Error.new(errors) unless errors.blank?
  end

  def self.set_address_params address
    {
      :Line1 => address.address1,
      :Line2 => address.address2,
      :City => address.city,
      :Region => ((address.state && address.state.abbr) || (address.state_name || '')),
      :PostalCode => address.zipcode,
      :Country => address.country && address.country.iso || ''
    }
  end
end
