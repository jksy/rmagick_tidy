require "spec_helper"

# A lazy body: an image is created while the server iterates it.
class LazyTestBody
  attr_reader :images

  def initialize(source = nil)
    @source = source
    @images = []
    @closed = false
  end

  def each
    img = @source ? @source.resize(2, 2) : Magick::Image.new(2, 2)
    @images << img
    yield img.columns.to_s
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end

  def to_path
    "/tmp/body"
  end
end

RSpec.describe RmagickTidy::Middleware do
  def stack
    RmagickTidy::Registry.stack
  end

  def call_with_body(body)
    described_class.new(->(_env) { [200, {}, body] }).call({})[2]
  end

  it "destroys images created by the app when an Array body is returned" do
    img = nil
    app = lambda do |_env|
      img = make_image
      [200, {}, ["ok"]]
    end
    status, _headers, body = described_class.new(app).call({})
    expect(status).to eq 200
    expect(body).to eq ["ok"]
    expect(img.destroyed?).to be true
    expect(stack).to be_empty
  end

  it "keeps the scope open until a lazy body is closed" do
    source = nil
    lazy = nil
    app = lambda do |_env|
      source = make_image
      lazy = LazyTestBody.new(source)
      [200, {}, lazy]
    end
    _status, _headers, body = described_class.new(app).call({})
    expect(source.destroyed?).to be false
    expect(stack.size).to eq 1

    expect(body.to_enum(:each).to_a).to eq ["2"]
    expect(lazy.images.first.destroyed?).to be false

    body.close
    expect(lazy.closed?).to be true
    expect(source.destroyed?).to be true
    expect(lazy.images.first.destroyed?).to be true
    expect(stack).to be_empty
  end

  it "tracks images created during iteration without an out-of-scope error" do
    RmagickTidy.configuration.strict_mode = :raise
    lazy = LazyTestBody.new
    body = call_with_body(lazy)
    expect { body.each { |_| nil } }.not_to raise_error
    body.close
    expect(lazy.images.first.destroyed?).to be true
  end

  it "ends its scope only once when the body is closed twice" do
    body = call_with_body(LazyTestBody.new)
    RmagickTidy::Registry.push
    body.close
    body.close
    expect(body.closed?).to be true
    expect(stack.size).to eq 1
  end

  it "ends the scope even when the body's close raises" do
    img = nil
    lazy = LazyTestBody.new
    lazy.define_singleton_method(:close) { raise "close failed" }
    app = lambda do |_env|
      img = make_image
      [200, {}, lazy]
    end
    _status, _headers, body = described_class.new(app).call({})
    expect { body.close }.to raise_error("close failed")
    expect(img.destroyed?).to be true
    expect(stack).to be_empty
  end

  it "destroys images and ends the scope when the app raises" do
    img = nil
    app = lambda do |_env|
      img = make_image
      raise "boom"
    end
    expect { described_class.new(app).call({}) }.to raise_error("boom")
    expect(img.destroyed?).to be true
    expect(stack).to be_empty
  end

  it "is not ended by a block scope around it that exits first" do
    source = nil
    app = lambda do |_env|
      source = make_image
      [200, {}, LazyTestBody.new(source)]
    end
    body = RmagickTidy.scope { described_class.new(app).call({})[2] }
    expect(source.destroyed?).to be false
    expect(stack.size).to eq 1
    body.close
    expect(source.destroyed?).to be true
    expect(stack).to be_empty
  end

  it "ends its scope on the stack it was pushed onto when closed from another thread" do
    body = call_with_body(LazyTestBody.new)
    Thread.new { body.close }.join
    expect(stack).to be_empty
  end

  describe RmagickTidy::Middleware::BodyProxy do
    it "forwards other methods to the body" do
      proxy = described_class.new(LazyTestBody.new) { nil }
      expect(proxy).to respond_to(:to_path)
      expect(proxy.to_path).to eq "/tmp/body"
    end

    it "does not expose to_ary or to_str" do
      body = Struct.new(:to_ary, :to_str).new([], "")
      proxy = described_class.new(body) { nil }
      expect(proxy).not_to respond_to(:to_ary)
      expect(proxy).not_to respond_to(:to_str)
      expect { proxy.to_ary }.to raise_error(NoMethodError)
    end

    it "runs the callback for a body that has no close method" do
      called = false
      described_class.new(Object.new) { called = true }.close
      expect(called).to be true
    end
  end
end
