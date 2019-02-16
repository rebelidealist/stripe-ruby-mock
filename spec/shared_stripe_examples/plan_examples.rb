require 'spec_helper'

shared_examples 'Plan API' do

  it "creates a stripe plan" do
    plan = Stripe::Plan.create(
      :id => 'pid_1',
      :product => {
        :name => 'The Mock Plan'
      },
      :amount => 9900,
      :currency => 'USD',
      :interval => 1,
      :metadata => {
        :description => "desc text",
        :info => "info text"
      },
      :trial_period_days => 30
    )

    expect(plan.id).to eq('pid_1')
    expect(plan.product).to match /test_prod_/
    product = Stripe::Product.retrieve(plan.product)
    expect(product.name).to eq('The Mock Plan')
    expect(product.type).to eq('service')
    expect(plan.amount).to eq(9900)

    expect(plan.currency).to eq('USD')
    expect(plan.interval).to eq(1)

    expect(plan.metadata.description).to eq('desc text')
    expect(plan.metadata.info).to eq('info text')

    expect(plan.trial_period_days).to eq(30)
  end

  it "creates a stripe plan with product id" do
    product = Stripe::Product.create(id: 'prod_1', name: 'Product One', type: 'good')

    plan = Stripe::Plan.create(
      :id => 'pid_1',
      :product => 'prod_1',
      :amount => 9900,
      :currency => 'USD',
      :interval => 1,
      :metadata => {
        :description => "desc text",
        :info => "info text"
      },
      :trial_period_days => 30
    )

    expect(plan.id).to eq('pid_1')
    expect(plan.product).to eq('prod_1')
    expect(Stripe::Product.retrieve('prod_1').name).to eq('Product One')
    expect(plan.amount).to eq(9900)

    expect(plan.currency).to eq('USD')
    expect(plan.interval).to eq(1)

    expect(plan.metadata.description).to eq('desc text')
    expect(plan.metadata.info).to eq('info text')

    expect(plan.trial_period_days).to eq(30)
  end

  it "raises error on unknown product" do
    expect { Stripe::Plan.create(
      :id => 'pid_1',
      :product => 'unknown_product',
      :amount => 9900,
      :currency => 'USD',
      :interval => 1,
      :metadata => {
        :description => "desc text",
        :info => "info text"
      },
      :trial_period_days => 30
    ) }.to raise_error(Stripe::InvalidRequestError, 'No such product: unknown_product')
  end

  it "creates a stripe plan without specifying ID" do
    plan = Stripe::Plan.create(
      :product => {
        :name => 'The Mock Plan'
      },
      :amount => 9900,
      :currency => 'USD',
      :interval => 1,
    )

    expect(plan.id).to match(/^test_plan/)
  end

  it "stores a created stripe plan in memory" do
    plan = Stripe::Plan.create(
      :id => 'pid_2',
      :product => {
        :name => 'The Memory Plan'
      },
      :amount => 1100,
      :currency => 'USD',
      :interval => 1
    )
    plan2 = Stripe::Plan.create(
      :id => 'pid_3',
      :product => {
        :name => 'The Bonk Plan',
      },
      :amount => 7777,
      :currency => 'USD',
      :interval => 1
    )
    data = test_data_source(:plans)
    products = test_data_source(:products)
    expect(data[plan.id]).to_not be_nil
    expect(data[plan.id][:amount]).to eq(1100)
    expect(data[plan.id][:product]).to match /prod_/
    expect(products[plan.product][:name]).to eq 'The Memory Plan'

    expect(data[plan2.id]).to_not be_nil
    expect(data[plan2.id][:amount]).to eq(7777)
    expect(data[plan2.id][:product]).to match /prod_/
    expect(products[plan2.product][:name]).to eq 'The Bonk Plan'
  end


  it "retrieves a stripe plan" do
    original = stripe_helper.create_plan(amount: 1331)
    plan = Stripe::Plan.retrieve(original.id)

    expect(plan.id).to eq(original.id)
    expect(plan.amount).to eq(original.amount)
  end


  it "updates a stripe plan" do
    stripe_helper.create_plan(id: 'super_member', amount: 111)

    plan = Stripe::Plan.retrieve('super_member')
    expect(plan.amount).to eq(111)

    plan.amount = 789
    plan.save
    plan = Stripe::Plan.retrieve('super_member')
    expect(plan.amount).to eq(789)
  end


  it "cannot retrieve a stripe plan that doesn't exist" do
    expect { Stripe::Plan.retrieve('nope') }.to raise_error {|e|
      expect(e).to be_a Stripe::InvalidRequestError
      expect(e.param).to eq('plan')
      expect(e.http_status).to eq(404)
    }
  end

  it "deletes a stripe plan" do
    stripe_helper.create_plan(id: 'super_member', amount: 111)

    plan = Stripe::Plan.retrieve('super_member')
    expect(plan).to_not be_nil

    plan.delete

    expect { Stripe::Plan.retrieve('super_member') }.to raise_error {|e|
      expect(e).to be_a Stripe::InvalidRequestError
      expect(e.param).to eq('plan')
      expect(e.http_status).to eq(404)
    }
  end

  it "retrieves all plans" do
    stripe_helper.create_plan(id: 'Plan One', amount: 54321)
    stripe_helper.create_plan(id: 'Plan Two', amount: 98765)

    all = Stripe::Plan.all
    expect(all.count).to eq(2)
    expect(all.map &:id).to include('Plan One', 'Plan Two')
    expect(all.map &:amount).to include(54321, 98765)
  end

  it 'retrieves plans with limit' do
    101.times do | i|
      stripe_helper.create_plan(id: "Plan #{i}", amount: 11)
    end
    all = Stripe::Plan.all(limit: 100)

    expect(all.count).to eq(100)
  end

  it 'validates the amount' do
    expect {
      Stripe::Plan.create(
        :id => 'pid_1',
        :product => {
          :name => 'The Mock Plan'
        },
        :amount => 99.99,
        :currency => 'USD',
        :interval => 'month'
      )
    }.to raise_error(Stripe::InvalidRequestError, "Invalid integer: 99.99")
  end

  describe "Validation", :live => true do
    let(:params) { stripe_helper.create_plan_params }
    let(:subject) { Stripe::Plan.create(params) }

    describe "Required Parameters" do
      after do
        params.delete(@name)
        message =
          if @name == :amount
            "Plans require an `#{@name}` parameter to be set."
          else
            "Missing required param: #{@name}."
          end
        expect { subject }.to raise_error(Stripe::InvalidRequestError, message)
      end

      it("requires a product") { @name = :product }
      it("requires an amount") { @name = :amount }
      it("requires a currency") { @name = :currency }
      it("requires an interval") { @name = :interval }
    end

    describe "Uniqueness" do

      it "validates for uniqueness" do
        stripe_helper.delete_plan(params[:id])

        Stripe::Plan.create(params)
        expect {
          Stripe::Plan.create(params)
        }.to raise_error(Stripe::InvalidRequestError, "Plan already exists.")
      end
    end
  end

end
