module Spree
  LineItem.class_eval do

    def taxable?
      return !self.tax_category.nil?
    end

  end
end