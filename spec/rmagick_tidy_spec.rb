require "spec_helper"

RSpec.describe RmagickTidy do
  describe ".scope" do
    it "destroys images created inside the block" do
      img = nil
      RmagickTidy.scope do
        img = make_image
        nil
      end
      expect(img.destroyed?).to be true
    end

    it "keeps the image returned from the block" do
      result = RmagickTidy.scope do
        make_image
      end
      expect(result.destroyed?).to be false
      result.destroy!
    end

    it "destroys other images but keeps the return value" do
      original = nil
      resized = RmagickTidy.scope do
        original = make_image(20, 20)
        original.resize(5, 5)
      end
      expect(resized.destroyed?).to be false
      expect(original.destroyed?).to be true
      resized.destroy!
    end

    it "destroys images even when the block raises" do
      img = nil
      expect do
        RmagickTidy.scope do
          img = make_image
          raise "boom"
        end
      end.to raise_error("boom")
      expect(img.destroyed?).to be true
    end

    it "supports nested scopes (inner scope destroys only its own images)" do
      outer_img = nil
      inner_img = nil
      RmagickTidy.scope do
        outer_img = make_image
        RmagickTidy.scope do
          inner_img = make_image
          nil
        end
        expect(inner_img.destroyed?).to be true
        expect(outer_img.destroyed?).to be false
        nil
      end
      expect(outer_img.destroyed?).to be true
    end

    it "does not double-register bang methods (resize!)" do
      img = nil
      RmagickTidy.scope do
        img = make_image(20, 20)
        img.resize!(5, 5)
        nil
      end
      # destroy! should be called exactly once; even with rescue guard this
      # should not raise. Image should be destroyed.
      expect(img.destroyed?).to be true
    end

    it "tracks each element returned from Image.read" do
      images = nil
      RmagickTidy.scope do
        img = make_image
        blob = img.to_blob { |info| info.format = "PNG" }
        images = Magick::Image.from_blob(blob)
        nil
      end
      images.each { |i| expect(i.destroyed?).to be true }
    end

    it "isolates scopes between threads" do
      results = []
      mutex = Mutex.new
      threads = 2.times.map do
        Thread.new do
          RmagickTidy.scope do
            img = make_image
            sleep 0.05
            mutex.synchronize { results << img }
            nil
          end
        end
      end
      threads.each(&:join)
      expect(results.size).to eq(2)
      results.each { |i| expect(i.destroyed?).to be true }
    end
  end

  describe "return value traversal" do
    it "keeps images returned inside a nested Hash/Array structure" do
      kept_a = kept_b = throwaway = nil
      result = RmagickTidy.scope do
        kept_a = make_image
        kept_b = make_image
        throwaway = make_image
        { primary: kept_a, others: [kept_b] }
      end
      expect(result[:primary].destroyed?).to be false
      expect(result[:others].first.destroyed?).to be false
      expect(throwaway.destroyed?).to be true
      result[:primary].destroy!
      result[:others].first.destroy!
    end

    it "treats a nil return value as no-keep" do
      img = nil
      RmagickTidy.scope do
        img = make_image
        nil
      end
      expect(img.destroyed?).to be true
    end

    it "treats an empty array return value as no-keep" do
      img = nil
      result = RmagickTidy.scope do
        img = make_image
        []
      end
      expect(result).to eq([])
      expect(img.destroyed?).to be true
    end
  end

  describe "destroy_safely" do
    it "skips objects that report destroyed? == true" do
      stub = double("already_destroyed", destroyed?: true)
      expect(stub).not_to receive(:destroy!)
      RmagickTidy::Registry.destroy_safely(stub)
    end

    it "calls destroy! on objects without destroyed?" do
      stub = Object.new
      def stub.destroy! = @destroyed = true
      def stub.destroyed_called? = @destroyed
      RmagickTidy::Registry.destroy_safely(stub)
      expect(stub.destroyed_called?).to be true
    end

    it "swallows Magick::ImageMagickError raised by destroy!" do
      stub = Object.new
      def stub.destroyed? = false
      def stub.destroy! = raise(Magick::ImageMagickError, "boom")
      expect { RmagickTidy::Registry.destroy_safely(stub) }.not_to raise_error
    end

    it "does not swallow unrelated errors raised by destroy!" do
      stub = Object.new
      def stub.destroyed? = false
      def stub.destroy! = raise(ArgumentError, "unexpected")
      expect { RmagickTidy::Registry.destroy_safely(stub) }.to raise_error(ArgumentError)
    end
  end

  describe "strict mode" do
    it "warns when an image is created outside a scope (:warn)" do
      RmagickTidy.configuration.strict_mode = :warn
      expect { make_image.destroy! }.to output(/rmagick_tidy/).to_stderr
    end

    it "raises when an image is created outside a scope (:raise)" do
      RmagickTidy.configuration.strict_mode = :raise
      expect { make_image }.to raise_error(RmagickTidy::OutOfScopeError)
    end

    it "is silent by default (:off)" do
      expect { make_image.destroy! }.not_to output.to_stderr
    end
  end
end
