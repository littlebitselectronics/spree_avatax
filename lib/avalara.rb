require 'avalara/version'
require 'avalara/errors'
require 'avalara/configuration'

require 'avalara/api'

require 'avalara/types'
require 'avalara/request'
require 'avalara/response'

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

  def self.validates_address(address)
    uri = [endpoint, version, 'address', 'validate?'].join('/')

    uri += %Q(Line1=#{address.address1}&Line2=#{address.address2}&City=#{address.city}&Region=#{address.state.abbr}&PostalCode=#{address.zipcode}&Country=#{address.country.iso})

    response = API.get(uri,
                        :headers => API.headers_for('0'),
                        :basic_auth => authentication
    )

    return case response.code
             when 200..299
               Response::TaxAddress.new(response)
             when 400..599
               raise ApiError.new(Response::TaxAddress.new(response))
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
end
