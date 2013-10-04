class ApiResponder < ActionController::Responder
  def to_json
    if get?
      render json: resource.to_json
    elsif put?
      render status: 201, json: resource.to_json
    elsif delete?
      if resource
        render status: 204, json: {}
      else
        render status: 410, json: {}
      end
    else
      default_render
    end
  end
end
