require "spec_helper"

# Stands in for ActiveJob::Base: records the around_perform callback and runs
# perform through it. Like ActiveSupport's run_callbacks, perform_now returns
# perform's value, not the around callback's.
class FakeActiveJob
  class << self
    attr_reader :around_perform_callback

    def around_perform(&block)
      @around_perform_callback = block
    end
  end

  def perform_now(*args)
    value = nil
    self.class.around_perform_callback.call(self, -> { value = perform(*args) })
    value
  end
end

RSpec.describe RmagickTidy::JobExtension do
  def job_class(&perform)
    Class.new(FakeActiveJob) do
      include RmagickTidy::JobExtension

      define_method(:perform, &perform)
    end
  end

  it "registers an around_perform callback when included" do
    expect(job_class { nil }.around_perform_callback).to be_a(Proc)
  end

  it "destroys images created in perform and passes the return value through" do
    img = nil
    job = job_class do |n|
      img = Magick::Image.new(n, n)
      :done
    end
    expect(job.new.perform_now(4)).to eq :done
    expect(img.destroyed?).to be true
    expect(RmagickTidy::Registry.stack).to be_empty
  end

  it "destroys images when perform raises" do
    img = nil
    job = job_class do
      img = Magick::Image.new(2, 2)
      raise "boom"
    end
    expect { job.new.perform_now }.to raise_error("boom")
    expect(img.destroyed?).to be true
  end

  it "destroys an image returned from perform too" do
    job = job_class { Magick::Image.new(2, 2) }
    expect(job.new.perform_now.destroyed?).to be true
  end
end

RSpec.describe RmagickTidy::Sidekiq::ServerMiddleware do
  it "runs the job inside a scope and destroys every image it created" do
    img = nil
    described_class.new.call(Object.new, {}, "default") { img = make_image }
    expect(img.destroyed?).to be true
    expect(RmagickTidy::Registry.stack).to be_empty
  end

  it "tracks images created in the job under strict mode :raise" do
    RmagickTidy.configuration.strict_mode = :raise
    expect { described_class.new.call(Object.new, {}, "default") { make_image } }.not_to raise_error
  end

  it "destroys images when the job raises" do
    img = nil
    expect do
      described_class.new.call(Object.new, {}, "default") do
        img = make_image
        raise "boom"
      end
    end.to raise_error("boom")
    expect(img.destroyed?).to be true
  end
end
