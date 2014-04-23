module Spree
  LineItem.class_eval do

    def taxable?
      return !self.tax_category.nil? or !self.is_gift_card?
    end

  end
end