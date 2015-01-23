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

  def self.validate_address(address)
    uri = [endpoint, version, 'address', 'validate?'].join('/')

    uri += set_address_params(address)

    response = API.get(uri,
                        :headers => API.headers_for('0'),
                        :basic_auth => authentication
    )

    return case response.code
             when 200..299
               valid_zip_code?(address, response["Address"])
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

  def self.valid_zip_code? address, response_address
    postal_code = response_address["PostalCode"].split('-')[0]
    raise Error.new('Invalid ZIP/Postal Code.') unless postal_code.eql?(address.zipcode)
  end

  def self.set_address_params address
    line1 = address.address1.gsub(/[\s#]/, ' ' => '+', '#' => '')
    line2 = address.address2.gsub(/[\s#]/, ' ' => '+', '#' => '')
    city = address.city.gsub(/[\s#]/, ' ' => '+', '#' => '')
    state = ((address.state && address.state.abbr) || (address.state_name || '')).gsub(/[\s#]/, ' ' => '+', '#' => '')
    zip_code = address.zipcode.gsub(/[\s#]/, ' ' => '+', '#' => '')
    country = address.country.iso.gsub(/[\s#]/, ' ' => '+', '#' => '')

    %Q(Line1=#{line1}&Line2=#{line2}&City=#{city}&Region=#{state}&PostalCode=#{zip_code}&Country=#{country})
  end
end
