require 'lib/git_tracking'

describe GitTracking::Config do
  after(:each) { File.delete(".git_tracking") if File.exists?(".git_tracking") }
  let(:config) { GitTracking::Config.new }

  it "#initialize should merge in config from .git_tracking file" do
    config_hash = config.instance_variable_get("@config")
    config_hash.should == {
        :raise_on_incomplete_merge => true,
        :raise_on_debugger => true,
        :emails => [],
        :keys => {}
    }
    special_options = {
      :raise_on_incomplete_merge => false,
      :raise_on_debugger => false,
      :emails => ["your@mom.com"]
    }
    File.open(".git_tracking", "w") do |file|
      YAML.dump(special_options, file)
    end
    GitTracking::Config.new.instance_variable_get("@config").should == config_hash.merge(special_options)
  end

  it "#raise_on_debugger should return the correct config value" do
    config.instance_eval { @config[:raise_on_debugger] = true }
    config.raise_on_debugger.should be_true
    config.instance_eval { @config[:raise_on_debugger] = false }
    config.raise_on_debugger.should be_false
  end

  it "#raise_on_incomplete_merge should return the correct config value" do
    config.instance_eval { @config[:raise_on_incomplete_merge] = true }
    config.raise_on_incomplete_merge.should be_true
    config.instance_eval { @config[:raise_on_incomplete_merge] = false }
    config.raise_on_incomplete_merge.should be_false
  end

  it "#emails should return an array of email addresses" do
    config.instance_eval { @config[:emails] = ["foo@bar.com", "baz@bang.com"] }
    config.emails.should == ["foo@bar.com", "baz@bang.com"]
  end

  describe "#add_email" do
    it "should add the email and store it" do
      config.emails.should_not include("foo@bar.com")
      config.add_email("foo@bar.com")
      config.emails.should include("foo@bar.com")
      YAML.load_file(".git_tracking")[:emails].should include("foo@bar.com")
    end

    it "should not add the email twice" do
      config.instance_eval { @config[:emails] = ["foo@bar.com", "baz@bang.com"] }
      config.add_email("foo@bar.com")
      config.emails.should == ["foo@bar.com", "baz@bang.com"]
    end
  end

  describe "#project_id" do
    it "should return the project_id" do
      config.instance_eval { @config[:project_id] = '7472' }
      config.project_id.should == '7472'
    end

    it "should set the project id and store it" do
      config.project_id('8765').should == '8765'
      YAML.load_file(".git_tracking")[:project_id].should == '8765'
    end
  end

  describe "#key_for_email" do
    it "should return the pivotal api key" do
      config.instance_eval do
        @config[:keys] = {
          "foo@bar.com" => "kdslghj348",
          "baz@bang.com" => "dsgkj39dk3"
        }
      end
      config.key_for_email("foo@bar.com").should == 'kdslghj348'
    end

    it "should set the pivotal api key and store it" do
      config.key_for_email("foo@bar.com", 'kdslghj348')
      YAML.load_file(".git_tracking")[:keys]["foo@bar.com"].should == 'kdslghj348'
    end
  end

  it "#write_to_file should write the @config var to the file" do
    special_options = {
      :raise_on_incomplete_merge => false,
      :raise_on_debugger => false,
      :emails => ["your@mom.com"]
    }
    config.instance_variable_set("@config", special_options)
    config.write_to_file
    YAML.load_file(".git_tracking") == special_options
  end
end

