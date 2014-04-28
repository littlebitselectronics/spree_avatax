module Spree
  TaxRate.class_eval do

    # Creates necessary tax adjustments for the order.
    def adjust(order, item)
      label = create_label
      if order.tax_zone.name =~ /Avalara/
        order.adjustments.tax.delete_all
        order.commit_avatax_invoice('SalesOrder') if order.ship_address
      else
        amount = compute_amount(item)
        return if amount == 0

        included = included_in_price && default_zone_or_zone_match?(item)

        if amount < 0
          label = Spree.t(:refund) + ' ' + create_label
        end

        self.adjustments.create!({
          :adjustable => item,
          :amount => amount,
          :order => order,
          :label => label || create_label,
          :included => included
        })
      end
    end

  end
end
