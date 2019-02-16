module StripeMock
  module RequestHandlers
    module ParamValidators

      def validate_create_plan_params(params)
        params[:id] = params[:id].to_s

        @base_strategy.create_plan_params.keys.each do |name|
          message =
            if name == :amount
              "Plans require an `#{name}` parameter to be set."
            else
              "Missing required param: #{name}."
            end
          raise Stripe::InvalidRequestError.new(message, name) if params[name].nil?
        end

        if plans[ params[:id] ]
          raise Stripe::InvalidRequestError.new("Plan already exists.", :id)
        end

        unless params[:amount].integer?
          raise Stripe::InvalidRequestError.new("Invalid integer: #{params[:amount]}", :amount)
        end
      end

      def validate_create_product_params(params)
        @base_strategy.create_product_params.keys.each do |name|
          message = "Missing required param: #{name}."
          raise Stripe::InvalidRequestError.new(message, name) if params[name].nil?
        end

        if products[ params[:id] ]
          raise Stripe::InvalidRequestError.new("Product already exists.", :id)
        end

        unless %w(good service).include? params[:type]
          raise Stripe::InvalidRequestError.new("Invalid type: must be one of good or service", :type)
        end
      end
    end
  end
end
