require "./scalar_param"

# Represents form data with a request's body.  See `ARTA::RequestParam`.
struct Athena::Routing::Params::RequestParam(T) < Athena::Routing::Params::ScalarParam
  # This is included here because of https://github.com/crystal-lang/crystal/issues/7584
  include Athena::Routing::Params::ParamInterface

  define_initializer

  # :inherit:
  def extract_value(request : HTTP::Request, default : _ = nil)
    request_data = request.request_data

    return default unless request_data.has_key? self.key

    if self.type <= Array
      request_data.fetch_all self.key
    else
      request_data[self.key]
    end
  end
end
