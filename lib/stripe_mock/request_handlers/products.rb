module StripeMock
  module RequestHandlers
    module Products

      def Products.included(klass)
        klass.add_handler 'post /v1/products',        :new_product
        klass.add_handler 'post /v1/products/(.*)',   :update_product
        klass.add_handler 'get /v1/products/(.*)',    :get_product
        klass.add_handler 'delete /v1/products/(.*)', :delete_product
        klass.add_handler 'get /v1/products',         :list_products
      end

      def new_product(route, method_url, params, headers)
        params[:id] ||= new_id('prod')
        validate_create_product_params(params)
        products[ params[:id] ] = Data.mock_product(params)
      end

      def update_product(route, method_url, params, headers)
        route =~ method_url
        assert_existence :product, $1, products[$1]
        products[$1].merge!(params)
      end

      def get_product(route, method_url, params, headers)
        route =~ method_url
        assert_existence :product, $1, products[$1]
      end

      def delete_product(route, method_url, params, headers)
        route =~ method_url
        assert_existence :product, $1, products.delete($1)
      end

      def list_products(route, method_url, params, headers)
        limit = params[:limit] ? params[:limit] : 10
        Data.mock_list_object(products.values.first(limit), limit: limit)
      end
    end
  end
end
