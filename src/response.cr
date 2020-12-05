# Represents an HTTP response that should be returned to the client.
#
# Contains the content, status, and headers that should be applied to the actual `HTTP::Server::Response`.
# This type is used to allow the content, status, and headers to be mutated by `ART::Listeners` before being returned to the client.
#
# The content is stored in a proc that gets called when `self` is being written to the response IO.
# How the output gets written can be customized via an `ART::Response::Writer`.
class Athena::Routing::Response
  # Determines how the content of an `ART::Response` will be written to the requests' response `IO`.
  #
  # By default the content is written directly to the requests' response `IO` via `ART::Response::DirectWriter`.
  # However, custom writers can be implemented to customize that behavior.  The most common use case would be for compression.
  #
  # Writers can also be defined as services and injected into a listener if they require additional external dependencies.
  #
  # ### Example
  #
  # ```
  # require "athena"
  # require "compress/gzip"
  #
  # # Define a custom writer to gzip the response
  # struct GzipWriter < ART::Response::Writer
  #   def write(output : IO, & : IO -> Nil) : Nil
  #     Compress::Gzip::Writer.open(output) do |gzip_io|
  #       yield gzip_io
  #     end
  #   end
  # end
  #
  # # Define a new event listener to handle applying this writer
  # @[ADI::Register]
  # struct CompressionListener
  #   include AED::EventListenerInterface
  #
  #   def self.subscribed_events : AED::SubscribedEvents
  #     AED::SubscribedEvents{
  #       ART::Events::Response => -256, # Listen on the Response event with a very low priority
  #     }
  #   end
  #
  #   def call(event : ART::Events::Response, dispatcher : AED::EventDispatcherInterface) : Nil
  #     # If the request supports gzip encoding
  #     if event.request.headers.includes_word?("accept-encoding", "gzip")
  #       # Change the `ART::Response` object's writer to be our `GzipWriter`
  #       event.response.writer = GzipWriter.new
  #
  #       # Set the encoding of the response to gzip
  #       event.response.headers["content-encoding"] = "gzip"
  #     end
  #   end
  # end
  #
  # class ExampleController < ART::Controller
  #   @[ART::Get("/users")]
  #   def users : Array(User)
  #     User.all
  #   end
  # end
  #
  # ART.run
  #
  # # GET /users # => [{"id":1,...},...] (gzipped)
  # ```
  abstract struct Writer
    # Accepts an *output* `IO` that the content of the response should be written to.
    abstract def write(output : IO, & : IO -> Nil) : Nil
  end

  # The default `ART::Response::Writer` for an `ART::Response`.
  #
  # Writes directly to the *output* `IO`.
  struct DirectWriter < Writer
    # :inherit:
    #
    # The *output* `IO` is yielded directly.
    def write(output : IO, & : IO -> Nil) : Nil
      yield output
    end
  end

  # See `ART::Response::Writer`.
  setter writer : ART::Response::Writer = ART::Response::DirectWriter.new

  # The `HTTP::Status` of `self.`
  getter status : HTTP::Status

  # The response headers on `self.`
  getter headers : HTTP::Headers

  # Stores the callback that run when `self` is being written to the `HTTP::Server::Response`.
  @content_callback : Proc(IO, Nil)

  # The cached string representation of the content.
  #
  # Is reset if the content of `self` changes.
  @content_string : String? = nil

  # Creates a new response with optional *status*, and *headers* arguments.
  #
  # The block is captured and called when `self` is being written to the response `IO`.
  # This can be useful to reduce memory overhead when needing to return large responses.
  #
  # ```
  # require "athena"
  #
  # class ExampleController < ART::Controller
  #   @[ART::Get("/users")]
  #   def users : ART::Response
  #     ART::Response.new headers: HTTP::Headers{"content-type" => "application/json"} do |io|
  #       User.all.to_json io
  #     end
  #   end
  # end
  #
  # ART.run
  #
  # # GET /users # => [{"id":1,...},...]
  # ```
  def self.new(status : HTTP::Status | Int32 = HTTP::Status::OK, headers : HTTP::Headers = HTTP::Headers.new, &block : IO -> Nil)
    new block, status, headers
  end

  # Creates a new response with optional *content*, *status*, and *headers* arguments.
  #
  # A proc is created that will print the given *content* to the response IO.
  def initialize(content : String? = nil, status : HTTP::Status | Int32 = HTTP::Status::OK, @headers : HTTP::Headers = HTTP::Headers.new)
    @status = HTTP::Status.new status
    @content_callback = Proc(IO, Nil).new { |io| io.print content }
  end

  # Creates a new response with the provided *content_callback* and optional *status*, and *headers* arguments.
  #
  # The proc is called when `self` is being written to the response IO.
  def initialize(@content_callback : Proc(IO, Nil), status : HTTP::Status | Int32 = HTTP::Status::OK, @headers : HTTP::Headers = HTTP::Headers.new)
    @status = HTTP::Status.new status
  end

  # Writes content of `self` to the provided *output*.
  #
  # How the output gets written can be customized via an `ART::Response::Writer`.
  def write(output : IO) : Nil
    @writer.write(output) do |writer_io|
      @content_callback.call writer_io
    end
  end

  # Updates the content of `self`.
  #
  # Resets the cached content string.
  def content=(@content_callback : Proc(IO, Nil))
    # Reset the content string if the content changes
    @content_string = nil
  end

  # :ditto:
  def content=(content : String? = nil) : Nil
    self.content = Proc(IO, Nil).new { |io| io.print content }
  end

  # Returns the content of `self` as a `String`.
  #
  # The content string is cached to avoid unnecessarily regenerating
  # the same string multiple times.
  #
  # The cached string is cleared when changing `self`'s content via `#content=`.
  def content : String
    @content_string ||= String.build do |io|
      write io
    end
  end

  # The `HTTP::Status` of `self.`
  def status=(code : HTTP::Status | Int32) : Nil
    @status = HTTP::Status.new code
  end

  def set_public : Nil
    @headers.add_cache_control_directive "public"
    @headers.remove_cache_control_directive "private"
  end

  def etag : String?
    @headers["etag"]?
  end

  def set_etag(etag : String? = nil, weak : Bool = false) : Nil
    if etag.nil?
      @headers.delete "etag"
      return
    end

    unless etag.includes? '"'
      etag = %("#{etag}")
    end

    @headers["etag"] = "#{weak ? "W/" : ""}#{etag}"
  end

  def last_modified : Time?
    if header = @headers["last-modified"]?
      Time::Format::HTTP_DATE.parse header
    end
  end

  def last_modified=(time : Time? = nil) : Nil
    if time.nil?
      @headers.delete "last-modified"
      return
    end

    @headers["last-modified"] = Time::Format::HTTP_DATE.format(time)
  end

  protected def prepare(request : HTTP::Request) : Nil
  end
end
