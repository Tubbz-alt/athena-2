# Responsible for resolving the arguments that will be passed to a controller action.
#
# See the [external documentation](https://athenaframework.org/components/#argument-resolution) for more information.
module Athena::Routing::Arguments::ArgumentResolverInterface
  # Returns an array of arguments resolved from the provided *request* for the given *route*.
  abstract def get_arguments(request : HTTP::Request, route : ART::ActionBase) : Array
end
