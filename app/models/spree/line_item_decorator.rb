module Spree
  LineItem.class_eval do

    def taxable?
      self.tax_category.nil? or self.is_gift_card? ? false : true
    end

  end
end