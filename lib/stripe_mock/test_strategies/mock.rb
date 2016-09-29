module StripeMock
  module TestStrategies
    class Mock < Base

      def create_plan(params={})
        Stripe::Plan.create create_plan_params(params)
      end

      def delete_plan(plan_id)
        if StripeMock.state == 'remote'
          StripeMock.client.destroy_resource('plans', plan_id)
        elsif StripeMock.state == 'local'
          StripeMock.instance.plans.delete(plan_id)
        end
      end

      def renew_subscriptions(subscription_list = [])
        if StripeMock.state == 'remote'
          StripeMock.client.renew_subscriptions(subscription_list)
        elsif StripeMock.state == 'local'
          StripeMock.instance.renew_subscriptions(subscription_list)
        end
      end

    end
  end
end
