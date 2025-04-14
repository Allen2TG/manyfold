module ManyfoldApi::V0
  class BaseDeserializer
    def initialize(object)
      @object = object
    end

    def deserialize
      raise NotImplementedError
    end

    def self.schema_ref_name
      name.underscore.split("/").last.gsub("_deserializer", "_request")
    end

    def self.schema_ref
      {"$ref" => "#/components/schemas/#{schema_ref_name}"}
    end

    def self.schema
      raise NotImplementedError
    end

    def dereference(id, type)
      route_options = Rails.application.routes.recognize_path(id)
      if route_options[:controller] == type.name.downcase.pluralize
        type.find_param(route_options[:id])
      end
    rescue ActionController::RoutingError, ActiveRecord::RecordNotFound
    end
  end
end
