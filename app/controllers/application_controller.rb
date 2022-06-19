class ApplicationController < ActionController::API
  def hello
    render json: { say: "Hello" }
  end
end
