# These live here so `Athena::Routing::View` is correctly created as a class versus a module.

abstract class Athena::Routing::ViewBase; end

class Athena::Routing::View(T) < Athena::Routing::ViewBase; end

module Athena::Routing::View::FormatHandlerInterface
  TAG = "athena.format_handler"

  # Apply `TAG` to all `ART::View::FormatHandlerInterface` instances automatically.
  ADI.auto_configure Athena::Routing::View::FormatHandlerInterface, {tags: [Athena::Routing::View::FormatHandlerInterface::TAG]}

  abstract def format : String

  abstract def call(view_handler : ART::View::ViewHandlerInterface, view : ART::View, request : HTTP::Request, format : String) : ART::Response
end
