# Represents a request parameter; e.x. query param, form data, a file, etc.
#
# See `ARTA::QueryParam` and `ARTA::RequestParam`.
module Athena::Routing::Params::ParamInterface
  # Returns the name of the parameter, maps to the controller action argument name.
  abstract def name : String

  # Returns the value that should be used if `#strict?` is false and the parameter was not provided, defaulting to `nil`.
  abstract def default

  # Returns a human readable summary of what the parameter is used for.
  # In the future this may be used to supplement auto generated endpoint documentation.
  abstract def description : String?

  # Returns the parameters that may not be present at the same time as `self`.  See [ARTA::QueryParam@incompatibles](../QueryParam.html#incompatibles).
  abstract def incompatibles : Array(String)?

  # Returns the `AVD::Constraint`s that should be used to validate the parameter's value.
  abstract def constraints : Array(AVD::Constraint)

  # Denotes whether `self` should be processed strictly.  See [ARTA::QueryParam@strict](../QueryParam.html#strict).
  abstract def strict? : Bool

  # Returns the `self`'s value from the provided *request*, or *default* if it was not present.
  abstract def extract_value(request : HTTP::Request, default : _ = nil)
end
