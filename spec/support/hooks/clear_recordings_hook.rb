RSpec.configure do |config|
  config.before(:example) do
    clear_recordings_dir
  end
end
