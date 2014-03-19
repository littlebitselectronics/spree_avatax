module Spree
  TaxRate.class_eval do

    # Creates necessary tax adjustments for the order.
    def adjust(order)
      label = create_label
      if order.tax_zone.name =~ /Avalara/
        order.commit_avatax_invoice if order.ship_address
      else
        if included_in_price
          if Zone.default_tax.contains? order.tax_zone
            order.line_items.each { |line_item| create_adjustment(label, line_item, line_item) }
          else
            amount = -1 * calculator.compute(order)
            label = Spree.t(:refund) + label
            order.adjustments.create({ amount: amount,
                                       source: order,
                                       originator: self,
                                       state: "closed",
                                       label: label }, without_protection: true)
          end
        else
          create_adjustment(label, order, order)
        end

      end
    end
      
  end
end
