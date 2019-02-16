module StripeMock
  module TestStrategies
    class Live < Base

      def create_plan(params={})
        raise "create_plan requires an :id" if params[:id].nil?
        delete_plan(params[:id])
        Stripe::Plan.create create_plan_params(params)
      end

      def delete_plan(plan_id)
        begin
          plan = Stripe::Plan.retrieve(plan_id)
          plan.delete
        rescue Stripe::StripeError => e
          # Do nothing; we just want to make sure this plan ceases to exists
        end
      end

      def create_product(params={})
        raise "create_product requires an :id" if params[:id].nil?
        delete_product(params[:id])
        Stripe::Product.create create_product_params(params)
      end

      def delete_product(product_id)
        begin
          product = Stripe::Product.retrieve(product_id)
          product.delete
        rescue Stripe::StripeError => e
          # Do nothing; we just want to make sure this product ceases to exists
        end
      end

      def create_coupon(params={})
        delete_coupon create_coupon_params(params)[:id]
        super
      end

      def delete_coupon(id)
        begin
          coupon = Stripe::Coupon.retrieve(id)
          coupon.delete
        rescue Stripe::StripeError
          # do nothing
        end
      end

      def upsert_stripe_object(object, attributes)
        raise UnsupportedRequestError.new "Updating or inserting Stripe objects in Live mode not supported"
      end

    end
  end
end
