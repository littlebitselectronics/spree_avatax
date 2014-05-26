module Spree
  LineItem.class_eval do

    def taxable?
      self.tax_category.nil? ? false : true
    end

  end
end