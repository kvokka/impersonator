module Impersonator
  module Api
    def recording(label, disabled: false, &block)
      @current_recording = ::Impersonator::Recording.new(label, disabled: disabled, recordings_path: configuration.recordings_path)
      @current_recording.start
      yield
    ensure
      @current_recording.finish
      @current_recording = nil
    end

    def current_recording
      @current_recording
    end

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    # Reset configuration and other global state
    def reset
      @current_recording = nil
      @configuration = nil
    end

    def impersonate(object, *methods)
      raise Impersonator::Errors::ConfigurationError, 'You must start a recording to impersonate objects. Use Impersonator.recording {}' unless @current_recording
      ::Impersonator::Proxy.new(object, recording: current_recording, impersonated_methods: methods)
    end
  end
end
