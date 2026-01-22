require 'rails_helper'

RSpec.describe "FareNegotiations", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/fare_negotiations/index"
      expect(response).to have_http_status(:success)
    end
  end

end
