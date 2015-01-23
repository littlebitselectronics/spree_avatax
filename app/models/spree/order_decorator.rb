module Spree
  Order.class_eval do

    #moved to main app
    #Spree::Order.state_machine.after_transition :to => :complete, :do => :create_invoice

    def create_invoice
      if self.tax_zone.name =~ /Avalara/ && payments.select{|p| p.payment_method.type == 'Spree::PaymentMethod::NoCharge' }.empty?
        commit_avatax_invoice('SalesInvoice')
      end
    end

    def commit_avatax_invoice(doc_type)

      begin
        matched_line_items = self.line_items.select do |line_item|
          line_item.taxable?
        end

        invoice_lines =[]
        line_count = 0

        discount = 0
        credits = self.adjustments.select {|a| a.amount < 0 && a.source_type == 'Spree::PromotionAction'}
        discount = -(credits.sum &:amount)
        matched_line_items.each do |matched_line_item|
          line_count = line_count + 1
          matched_line_amount = matched_line_item.price * matched_line_item.quantity
          invoice_line = Avalara::Request::Line.new(
              :line_no => line_count.to_s,
              :destination_code => '1',
              :origin_code => '1',
              :qty => matched_line_item.quantity.to_s,
              :amount => matched_line_amount.to_s,
              :discounted => true,
              :item_code => matched_line_item.variant.sku,
              :tax_code => matched_line_item.is_gift_card? ? 'NT' : ''
          )
          invoice_lines << invoice_line
        end

        invoice_line = Avalara::Request::Line.new(
            :line_no => (line_count + 1).to_s,
            :destination_code => '1',
            :origin_code => '1',
            :qty => 1,
            :amount => self.ship_total.to_s,
            :tax_code => 'FR',
            :discounted => true,
            :item_code => 'SHIPPING'
        )
        invoice_lines << invoice_line

        invoice_addresses = []
        invoice_address = Avalara::Request::Address.new(
            :address_code => '1',
            :line_1 => self.ship_address.address1.to_s,
            :line_2 => self.ship_address.address2.to_s,
            :city => self.ship_address.city.to_s,
            :postal_code => self.ship_address.zipcode.to_s
        )
        invoice_addresses << invoice_address

        exemption_no = self.user.try(:tax_exempt) ? 'TRUE' : nil

        invoice = Avalara::Request::Invoice.new(
            :customer_code => self.email,
            :doc_date => Date.today,
            :doc_type => doc_type,
            :doc_code => self.number,
            :company_code => AvataxConfig.company_code,
            :reference_code => self.number,
            :commit => 'true',
            :discount => discount,
            :exemption_no => exemption_no
        )

        invoice.addresses = invoice_addresses
        invoice.lines = invoice_lines

        Rails.logger.info "Avatax POST started"
        invoice_tax = Avalara.get_tax(invoice)
        #Tax
        if doc_type == 'SalesOrder'
          self.adjustments.tax.destroy_all
          tax_adjustment = self.adjustments.new
          tax_adjustment.label = "Tax"
          tax_adjustment.source_type = "Spree::TaxRate"
          tax_adjustment.amount = invoice_tax["total_tax"].to_f
          tax_adjustment.save!

          save!
        end

      rescue => error
        logger.debug 'Avatax Commit Failed!'
        logger.debug error.to_s
        raise Avalara::Error.new error.to_s
      end

    end

    def estimate_avatax(variant, quantity)

      begin

        invoice_lines =[]
        line_count = 0

        line_count = line_count + 1
        invoice_line = Avalara::Request::Line.new(
          :line_no => line_count.to_s,
          :destination_code => '1',
          :origin_code => '1',
          :qty => quantity.to_s,
          :amount => variant.price.to_s,
          :discounted => true,
          :item_code => variant.sku,
          :tax_code => ''
        )
        invoice_lines << invoice_line

        invoice_line = Avalara::Request::Line.new(
          :line_no => (line_count + 1).to_s,
          :destination_code => '1',
          :origin_code => '1',
          :qty => 1,
          :amount => self.ship_total.to_s,
          :tax_code => 'FR',
          :discounted => true,
          :item_code => 'SHIPPING'
        )
        invoice_lines << invoice_line

        invoice_addresses = []
        invoice_address = Avalara::Request::Address.new(
          :address_code => '1',
          :line_1 => self.ship_address.address1.to_s,
          :line_2 => self.ship_address.address2.to_s,
          :city => self.ship_address.city.to_s,
          :postal_code => self.ship_address.zipcode.to_s
        )
        invoice_addresses << invoice_address

        invoice = Avalara::Request::Invoice.new(
          :customer_code => self.email,
          :doc_date => Date.today,
          :doc_type => 'SalesOrder',
          :doc_code => self.number,
          :company_code => AvataxConfig.company_code,
          :reference_code => self.number,
          :commit => 'true',
          :discount => 0.0,
          :exemption_no => nil
        )

        invoice.addresses = invoice_addresses
        invoice.lines = invoice_lines

        Rails.logger.info "Avatax Single - POST started"
        invoice_tax = Avalara.get_tax(invoice)

      rescue => error
        logger.debug 'Avatax Estimate Failed!'
        logger.debug error.to_s
      end

    end

    def validate_shipping_address
      Avalara.validate_address(self.shipping_address)
    end
  end
end
