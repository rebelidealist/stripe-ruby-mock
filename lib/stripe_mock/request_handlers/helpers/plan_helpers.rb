module StripeMock
  module RequestHandlers
    module Helpers

      def add_product(product)
        if product.is_a?(String)
          assert_existence :product, product, products[product]
          products[product]
        else
          id = new_id('prod')
          products[id] = Data.mock_product(product.merge(id: id))
        end
      end
    end
  end
end