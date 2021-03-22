module StripeMock
  module RequestHandlers
    module Customers

      def Customers.included(klass)
        klass.add_handler 'post /v1/customers',                     :new_customer
        klass.add_handler 'post /v1/customers/([^/]*)',             :update_customer
        klass.add_handler 'get /v1/customers/([^/]*)',              :get_customer
        klass.add_handler 'delete /v1/customers/([^/]*)',           :delete_customer
        klass.add_handler 'get /v1/customers',                      :list_customers
        klass.add_handler 'delete /v1/customers/([^/]*)/discount',  :delete_customer_discount
      end

      def new_customer(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        params[:id] ||= new_id('cus')
        sources = []

        if params[:source]
          new_card =
            if params[:source].is_a?(Hash)
              unless params[:source][:object] && params[:source][:number] && params[:source][:exp_month] && params[:source][:exp_year]
                raise Stripe::InvalidRequestError.new('You must supply a valid card', nil, http_status: 400)
              end
              card_from_params(params[:source])
            else
              get_card_or_bank_by_token(params.delete(:source))
            end
          sources << new_card
          params[:default_source] = sources.first[:id]
        end

        customers[stripe_account] ||= {}
        customers[stripe_account][params[:id]] = Data.mock_customer(sources, params)

        if params[:plan]
          plan_id = params[:plan].to_s
          plan = assert_existence :plan, plan_id, plans[plan_id]

          if params[:default_source].nil? && params[:trial_end].nil? && plan[:trial_period_days].nil? && plan[:amount] != 0
            raise Stripe::InvalidRequestError.new('You must supply a valid card', nil, http_status: 400)
          end

          subscription = Data.mock_subscription({ id: new_id('su') })
          subscription = resolve_subscription_changes(subscription, [plan], customers[stripe_account][params[:id]], params)
          add_subscription_to_customer(customers[stripe_account][params[:id]], subscription)
          subscriptions[subscription[:id]] = subscription
        elsif params[:trial_end]
          raise Stripe::InvalidRequestError.new('Received unknown parameter: trial_end', nil, http_status: 400)
        end

        if params[:coupon]
          coupon = coupons[params[:coupon]]
          assert_existence :coupon, params[:coupon], coupon
          add_coupon_to_object(customers[stripe_account][params[:id]], coupon)
        end

        customers[stripe_account][params[:id]]
      end

      def update_customer(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        route =~ method_url
        cus = assert_existence :customer, $1, customers[stripe_account][$1]

        # get existing and pending metadata
        metadata = cus.delete(:metadata) || {}
        metadata_updates = params.delete(:metadata) || {}

        # This is a workaround for the problematic way Stripe serialize objects
        #
        # Even though e.g. `sources` have not been modified, `params.sources`
        # contains an empty hash.
        #
        # Merging the `params`-hash directly with the customer, would
        # remove any sources already on the customer, even though no changes
        # were made to `sources`.
        #
        # For this reason, any params containing an empty hash needs to be
        # deleted. This also has to be done recursively, since some params
        # are nested, like `shipping.address`.
        delete_blank(params)

        # Stripe interprets empty strings as `nil`, so when a `param` is an
        # empty string, it means that the value should be set to `nil`.
        replace_empty_strings(params)

        cus.merge!(params)
        cus[:metadata] = {**metadata, **metadata_updates}

        if params[:source]
          if params[:source].is_a?(String)
            new_card = get_card_or_bank_by_token(params.delete(:source))
          elsif params[:source].is_a?(Stripe::Token)
            new_card = get_card_or_bank_by_token(params[:source][:id])
          elsif params[:source].is_a?(Hash)
            unless params[:source][:object] && params[:source][:number] && params[:source][:exp_month] && params[:source][:exp_year]
              raise Stripe::InvalidRequestError.new('You must supply a valid card', nil, http_status: 400)
            end
            new_card = card_from_params(params.delete(:source))
          end
          add_card_to_object(:customer, new_card, cus, true)
          cus[:default_source] = new_card[:id]
        end

        if params[:coupon]
          if params[:coupon] == ''
            delete_coupon_from_object(cus)
          else
            coupon = coupons[params[:coupon]]
            assert_existence :coupon, params[:coupon], coupon

            add_coupon_to_object(cus, coupon)
          end
        end

        cus
      end

      def delete_customer(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        route =~ method_url
        assert_existence :customer, $1, customers[stripe_account][$1]

        customers[stripe_account][$1] = {
          id: customers[stripe_account][$1][:id],
          deleted: true
        }
      end

      def get_customer(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        route =~ method_url
        customer = assert_existence :customer, $1, customers[stripe_account][$1]

        customer = customer.clone
        if params[:expand] == ['default_source'] && customer[:sources][:data]
          customer[:default_source] = customer[:sources][:data].detect do |source|
            source[:id] == customer[:default_source]
          end
        end

        customer
      end

      def list_customers(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        Data.mock_list_object(customers[stripe_account]&.values, params)
      end

      def delete_customer_discount(route, method_url, params, headers)
        stripe_account = headers && headers[:stripe_account] || Stripe.api_key
        route =~ method_url
        cus = assert_existence :customer, $1, customers[stripe_account][$1]

        cus[:discount] = nil

        cus
      end

      private

      # Deletes all keys with empty values from a hash
      def delete_blank(hash)
        hash.delete_if do |_k, v|
          v.instance_of?(Hash) && delete_blank(v).empty?
        end
      end

      # Traverses a hash, replacing all empty strings with `nil`
      def replace_empty_strings(hash)
        hash.each do |k, v|
          replace_empty_strings(v) if v.instance_of?(Hash)
          hash[k] = nil if v == ''
        end
      end
    end
  end
end
