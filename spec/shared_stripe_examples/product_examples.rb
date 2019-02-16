require 'spec_helper'

shared_examples 'Product API' do

  it "creates a stripe product" do
    product = Stripe::Product.create(
      :id => 'prod_1',
      :name => 'The Mock Product',
      :type => 'service',
      :description => 'Comfortable cotton t-shirt',
      :attributes => ['size', 'gender']
    )

    expect(product.id).to eq('prod_1')

    expect(product.name).to eq('The Mock Product')
    expect(product.type).to eq('service')

    expect(product.attributes).to eq(['size', 'gender'])
  end

  it "creates a stripe product without specifying ID" do
    product = Stripe::Product.create(
      :name => 'The Mock Product',
      :type => 'service',
      :description => 'Comfortable cotton t-shirt',
      :attributes => ['size', 'gender']
    )

    expect(product.id).to eq('test_prod_1')

    expect(product.name).to eq('The Mock Product')
    expect(product.type).to eq('service')

    expect(product.attributes).to eq(['size', 'gender'])
  end

  it "stores a created stripe product in memory" do
    product = Stripe::Product.create(
      :id => 'prod_1',
      :name => 'The Mock Product',
      :type => 'good',
      :description => 'Comfortable cotton t-shirt',
      :attributes => ['size', 'gender']
    )

    product2 = Stripe::Product.create(
      :id => 'prod_2',
      :name => 'The Bonk Service',
      :type => 'service',
      :description => 'Nice',
      :attributes => ['tastes']
    )

    data = test_data_source(:products)
    expect(data[product.id]).to_not be_nil
    expect(data[product.id][:type]).to eq('good')
    expect(data[product.id][:id]).to eq('prod_1')
    expect(data[product.id][:name]).to eq('The Mock Product')
    expect(data[product.id][:description]).to eq('Comfortable cotton t-shirt')
    expect(data[product.id][:attributes]).to eq(['size', 'gender'])

    expect(data[product2.id]).to_not be_nil
    expect(data[product2.id][:type]).to eq('service')
    expect(data[product2.id][:id]).to eq('prod_2')
    expect(data[product2.id][:name]).to eq('The Bonk Service')
    expect(data[product2.id][:description]).to eq('Nice')
    expect(data[product2.id][:attributes]).to eq(['tastes'])
  end


  it "retrieves a stripe product" do
    original = stripe_helper.create_product(name: 'Mock Product')
    product = Stripe::Product.retrieve(original.id)

    expect(product.id).to eq(original.id)
    expect(product.name).to eq('Mock Product')
  end


  it "updates a stripe product" do
    stripe_helper.create_product(id: 'super_member', name: 'Super !')

    product = Stripe::Product.retrieve('super_member')
    expect(product.name).to eq('Super !')

    product.name = 'Super membership !'
    product.save
    product = Stripe::Product.retrieve('super_member')
    expect(product.name).to eq('Super membership !')
  end


  it "cannot retrieve a stripe product that doesn't exist" do
    expect { Stripe::Product.retrieve('nope') }.to raise_error {|e|
      expect(e).to be_a Stripe::InvalidRequestError
      expect(e.param).to eq('product')
      expect(e.http_status).to eq(404)
    }
  end

  it "deletes a stripe product" do
    stripe_helper.create_product(id: 'super_member', amount: 111)

    product = Stripe::Product.retrieve('super_member')
    expect(product).to_not be_nil

    product.delete

    expect { Stripe::Product.retrieve('super_member') }.to raise_error {|e|
      expect(e).to be_a Stripe::InvalidRequestError
      expect(e.param).to eq('product')
      expect(e.http_status).to eq(404)
    }
  end

  it "retrieves all products" do
    stripe_helper.create_product(id: 'product One', type: 'good')
    stripe_helper.create_product(id: 'product Two', type: 'service')

    all = Stripe::Product.all
    expect(all.count).to eq(2)
    expect(all.map &:id).to include('product One', 'product Two')
    expect(all.map &:type).to include('good', 'service')
  end

  it 'retrieves products with limit' do
    101.times do | i|
      stripe_helper.create_product(id: "product #{i}", amount: 11)
    end
    all = Stripe::Product.all(limit: 100)

    expect(all.count).to eq(100)
  end

  it 'validates the type' do
    expect {
      Stripe::Product.create(
        :id => 'pid_1',
        :name => 'Fly boat',
        :type => 'fly'
      )
    }.to raise_error(Stripe::InvalidRequestError, "Invalid type: must be one of good or service")
  end

  describe "Validation", :live => true do
    let(:params) { stripe_helper.create_product_params }
    let(:subject) { Stripe::Product.create(params) }

    describe "Required Parameters" do
      after do
        params.delete(@name)
        message = "Missing required param: #{@name}."
        expect { subject }.to raise_error(Stripe::InvalidRequestError, message)
      end

      it("requires a name") { @name = :name }
      it("requires an type") { @name = :type }
    end

    describe "Uniqueness" do

      it "validates for uniqueness" do
        stripe_helper.delete_product(params[:id])

        Stripe::Product.create(params)
        expect {
          Stripe::Product.create(params)
        }.to raise_error(Stripe::InvalidRequestError, "Product already exists.")
      end
    end
  end

end
