# frozen_string_literal: true

module Impersonator
  class Recording
    include HasLogger

    attr_reader :label

    def initialize(label)
      @label = label
    end

    def start
      logger.debug "Starting recording #{label}..."
      if File.exist?(file_path)
        start_in_replay_mode
      else
        start_in_record_mode
      end
    end

    def record(method, return_value)
      method_invocation = MethodInvocation.new(method_instance: method, return_value: return_value)

      @method_invocations << method_invocation
    end

    def replay(method)
      method_invocation = @method_invocations.shift
      raise Impersonator::Errors::MethodInvocationError, "Unexpected method invocation received: #{method}" unless method_invocation

      validate_method_signature!(method, method_invocation.method_instance)
      replay_block(method_invocation, method)

      method_invocation.return_value
    end

    def finish
      logger.debug "Recording #{label} finished"
      if record_mode?
        finish_in_record_mode
      else
        finish_in_replay_mode
      end
    end

    def replay_mode?
      @replay_mode
    end

    def record_mode?
      !replay_mode?
    end

    private

    def replay_block(recorded_method_invocation, method_to_replay)
      block_spy = recorded_method_invocation.method_instance.block_spy
      block_spy&.block_invocations&.each do |block_invocation|
        method_to_replay.block.call(*block_invocation.arguments)
      end
    end

    def start_in_replay_mode
      logger.debug 'Replay mode'
      @replay_mode = true
      @method_invocations = YAML.load_file(file_path)
    end

    def start_in_record_mode
      logger.debug 'Recording mode'
      @replay_mode = false
      make_sure_fixtures_dir_exists
      @method_invocations = []
    end

    def finish_in_record_mode
      File.open(file_path, 'w') do |file|
        YAML.dump(@method_invocations, file)
      end
    end

    def finish_in_replay_mode
      unless @method_invocations.empty?
        raise Impersonator::Errors::MethodInvocationError, "Expecting #{@method_invocations.length} method invocations"\
                                                            " that didn't happen: #{@method_invocations.inspect}"
      end
    end

    def file_path
      "spec/recordings/#{label}.yml"
    end

    def make_sure_fixtures_dir_exists
      dirname = File.dirname(file_path)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
    end

    def validate_method_signature!(expected_method, actual_method)
      unless actual_method == expected_method
        raise Impersonator::Errors::MethodInvocationError, "Expecting method '#{expected_method}' but '#{actual_method}'"\
                                                            ' received'
      end
    end
  end
end
