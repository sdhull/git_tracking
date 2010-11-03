require 'lib/git_tracking'

describe GitTracking::Config do
  let(:config) { GitTracking::Config.new }
  it "raise_on_debugger should return the correct config value" do
    config.instance_eval { @config[:raise_on_debugger] = true }
    config.raise_on_debugger.should be_true
    config.instance_eval { @config[:raise_on_debugger] = false }
    config.raise_on_debugger.should be_false
  end
  it "raise_on_incomplete_merge should return the correct config value" do
    config.instance_eval { @config[:raise_on_incomplete_merge] = true }
    config.raise_on_incomplete_merge.should be_true
    config.instance_eval { @config[:raise_on_incomplete_merge] = false }
    config.raise_on_incomplete_merge.should be_false
  end
end

