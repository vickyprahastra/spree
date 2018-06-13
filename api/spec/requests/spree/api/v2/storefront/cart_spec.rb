require 'spec_helper'

describe 'API V2 Storefront Cart Spec', type: :request do
  let(:user) { create(:user) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let(:order) { Spree::Order.last }

  describe 'cart#create' do
    shared_examples 'creates an order' do
      it 'returns a proper HTTP status' do
        expect(response.status).to eq(201)
      end

      it 'returns a valid JSON response' do
        expect(json_response['data']).to have_id(order.id.to_s)
        expect(json_response['data']).to have_type('cart')
        expect(json_response['data']).to have_attribute(:number).with_value(order.number)
        expect(json_response['data']).to have_attribute(:state).with_value('cart')
        expect(json_response['data']).to have_attribute(:token).with_value(order.token)
        expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
      end
    end

    context 'for signed in user' do
      before do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart', headers: headers
      end

      it_behaves_like 'creates an order'

      it 'associates order with user' do
        expect(json_response['data']).to have_attribute(:user_id).with_value(user.id)
      end
    end

    context 'as guest user' do
      before do
        post '/api/v2/storefront/cart'
      end

      it_behaves_like 'creates an order'
    end
  end

  describe 'cart#add_item' do
    let(:variant) { create(:variant) }

    context 'without existing order' do
      it 'returns error' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers

        expect(response.status).to eq(422)
      end
    end

    context 'with existing order' do
      let!(:order) { create(:order, user: user) }

      it 'adds item to cart' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers

        expect(response.status).to eq(200)

        expect(order.line_items.count).to eq(1)
        expect(order.line_items.first.variant).to eq(variant)
        expect(order.line_items.first.quantity).to eq(5)

        expect(json_response['data']).to have_id(order.id.to_s)
        expect(json_response['data']).to have_type('cart')
        expect(json_response['data']).to have_attribute(:number).with_value(order.number)
        expect(json_response['data']).to have_attribute(:state).with_value('cart')
        expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
        expect(json_response['included']).to include(have_type('variant').and have_id(variant.id.to_s))
      end
    end

    context 'with existing guest order' do
      let(:custom_token) { 'custom_token' }
      let!(:order) { create(:order, token: custom_token) }

      it 'adds item to cart' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5, order_token: custom_token }, headers: headers

        expect(response.status).to eq(200)

        expect(order.line_items.count).to eq(1)
        expect(order.line_items.first.variant).to eq(variant)
        expect(order.line_items.first.quantity).to eq(5)

        expect(json_response['data']).to have_id(order.id.to_s)
        expect(json_response['data']).to have_type('cart')
        expect(json_response['data']).to have_attribute(:number).with_value(order.number)
        expect(json_response['data']).to have_attribute(:state).with_value('cart')
        expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
        expect(json_response['included']).to include(have_type('variant').and have_id(variant.id.to_s))
      end
    end
  end
end
