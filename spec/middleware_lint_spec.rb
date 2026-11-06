require "spec_helper"
require "stringio"
require "rack/lint"
require "rack/mock_request"

# Runs the middleware under Rack::Lint and reads the body the way a server
# does: with each when the body responds to it, otherwise as a Rack 3
# streaming body with call. Lint raises Rack::Lint::LintError on anything
# that breaks the Rack spec, including a body that was never closed.
RSpec.describe RmagickTidy::Middleware, "under Rack::Lint" do
  def serve(app)
    env = Rack::MockRequest.env_for("/")
    _status, _headers, body = Rack::Lint.new(described_class.new(app)).call(env)
    out = +""
    begin
      if body.respond_to?(:each)
        body.each { |chunk| out << chunk }
      else
        body.call(StringIO.new(out))
      end
    ensure
      body.close
    end
    out
  end

  def respond_with(body)
    ->(_env) { [200, { "content-type" => "text/plain" }, body] }
  end

  it "passes with an Array body" do
    img = nil
    app = lambda do |env|
      img = make_image
      respond_with(["w=#{img.columns}"]).call(env)
    end

    expect(serve(app)).to eq "w=4"
    expect(img).to be_destroyed
    expect(RmagickTidy::Registry.stack).to be_empty
  end

  it "passes with an enumerable body that creates images while it is iterated" do
    images = []
    body = Enumerator.new do |y|
      images << make_image
      y << "w=#{images.last.columns}"
    end

    expect(serve(respond_with(body))).to eq "w=4"
    expect(images).to all(be_destroyed)
    expect(RmagickTidy::Registry.stack).to be_empty
  end

  it "passes with a streaming body that creates images while it is called" do
    images = []
    body = lambda do |stream|
      images << make_image
      stream.write("w=#{images.last.columns}")
    ensure
      stream.close
    end

    expect(serve(respond_with(body))).to eq "w=4"
    expect(images).to all(be_destroyed)
    expect(RmagickTidy::Registry.stack).to be_empty
  end
end
