require 'spec_helper'
require_stripe_examples

describe 'StripeMock Server', :mock_server => true do

  let(:stripe_helper) { StripeMock.create_test_helper }

  it_behaves_like_stripe do
    def test_data_source(type); StripeMock.client.get_server_data(type); end
  end

  context "without arguments" do
    before(:all) do
      StripeMock.spawn_server
    end

    before do
      @client = StripeMock.start_client
    end

    after { StripeMock.stop_client(:clear_server_data => true) }


    it "uses an RPC client for mock requests" do
      charge = Stripe::Charge.create(
        amount: 987,
        currency: 'USD',
        card: stripe_helper.generate_card_token,
        description: 'card charge'
      )
      expect(charge.amount).to eq(987)
      expect(charge.currency).to eq('USD')
      expect(charge.description).to eq('card charge')
    end


    it "should not clear server data in between client sessions by default" do
      customer = Stripe::Customer.create(email: 'johnny@appleseed.com')
      expect(customer.email).to eq('johnny@appleseed.com')

      server_customer_data = StripeMock.client.get_server_data(:customers)[customer.id]
      expect(server_customer_data).to_not be_nil
      expect(server_customer_data[:email]).to eq('johnny@appleseed.com')

      StripeMock.stop_client
      StripeMock.start_client

      server_customer_data = StripeMock.client.get_server_data(:customers)[customer.id]
      expect(server_customer_data).to_not be_nil
      expect(server_customer_data[:email]).to eq('johnny@appleseed.com')
    end


    it "returns a response with symbolized hash keys" do
      stripe_helper.create_plan(id: 'x')
      response, api_key = StripeMock.redirect_to_mock_server('get', '/v1/plans/x', 'xxx')
      response.keys.each {|k| expect(k).to be_a(Symbol) }
    end


    it "can toggle debug" do
      StripeMock.toggle_debug(true)
      expect(@client.server_debug?).to eq(true)
      StripeMock.toggle_debug(false)
      expect(@client.server_debug?).to eq(false)
    end


    it "should toggle off debug when mock session ends" do
      StripeMock.toggle_debug(true)

      StripeMock.stop_client
      expect(StripeMock.client).to be_nil

      StripeMock.start_client
      expect(StripeMock.client.server_debug?).to eq(false)
    end


    it "can set the default server pid path" do
      expect(StripeMock.default_server_pid_path).to eq('./stripe-mock-server.pid')

      orig = StripeMock.default_server_pid_path
      StripeMock.default_server_pid_path = 'abc'
      expect(StripeMock.default_server_pid_path).to eq('abc')

      # Set back to original for #kill_server to work properly
      StripeMock.default_server_pid_path = orig
    end

    it "can set the default server log path" do
      expect(StripeMock.default_server_log_path).to eq('./stripe-mock-server.log')

      StripeMock.default_server_log_path = 'yule.log'
      expect(StripeMock.default_server_log_path).to eq('yule.log')
    end


    it "doesn't create multiple clients" do
      result = StripeMock.start_client
      expect(result.__id__).to eq(@client.__id__)
    end


    it "raises an error when client is stopped" do
      expect(@client).to be_a StripeMock::Client
      expect(@client.state).to eq('ready')

      StripeMock.stop_client
      expect(@client.state).to eq('closed')
      expect { @client.clear_server_data }.to raise_error StripeMock::ClosedClientConnectionError
    end


    it "raises an error when client connection is closed" do
      expect(@client).to be_a StripeMock::Client
      expect(@client.state).to eq('ready')

      @client.close!
      expect(@client.state).to eq('closed')
      expect(StripeMock.stop_client).to eq(false)
    end


    it "throws an error when server is not running" do
      StripeMock.stop_client
      begin
        StripeMock.start_client(1515)
        # We should never get here
        expect(false).to eq(true)
      rescue StripeMock::ServerTimeoutError => e
        expect(e.associated_error).to be_a(Errno::ECONNREFUSED)
      end
    end
  end

  context "with arguments" do
    it "preserves passed arguments" do
      ARGV << "--test"

      StripeMock.spawn_server

      expect(ARGV).to include "--test"
      ARGV.delete "--test"
    end
  end
end
