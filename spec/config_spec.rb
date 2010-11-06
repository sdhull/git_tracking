require 'lib/git_tracking'

describe GitTracking::Config do
  before(:all) do
    File.rename ".git_tracking", ".git_tracking.real" if File.exists?(".git_tracking")
    @orig_author = `git config user.name`.chomp
    @orig_last_api_key = `git config git-tracking.last-api-key`.chomp
    @orig_last_story_id = `git config git-tracking.last-story-id`.chomp
  end

  after(:all) do
    File.rename ".git_tracking.real", ".git_tracking" if File.exists?(".git_tracking.real")
    system "git config user.name '#{@orig_author}'"
    system "git config git-tracking.last-api-key '#{@orig_last_api_key}'"
    system "git config git-tracking.last-story-id '#{@orig_last_story_id}'"
  end

  after(:each) { File.delete(".git_tracking") if File.exists?(".git_tracking") }
  let(:config) { GitTracking::Config.new }

  it "#initialize should merge in config from .git_tracking file" do
    config_hash = config.instance_variable_get("@config")
    config_hash.should == {
        :raise_on_incomplete_merge => true,
        :raise_on_debugger => true,
        :authors => [],
        :keys => {}
    }
    special_options = {
      :raise_on_incomplete_merge => false,
      :raise_on_debugger => false
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
    config.instance_eval do
      @config[:keys] = {
        "foo@bar.com" => "alsdkjf91",
        "baz@bang.com" => "dsgkj39dk3"
      }
    end
    config.emails.should == ["foo@bar.com", "baz@bang.com"]
  end

  it "#author should return the user.name value from the git config" do
    system "git config user.name 'Steve'"
    config.author.should == 'Steve'
  end

  describe "#author=" do
    it "should set the user.name in the git config" do
      (config.author='Ghost').should == "Ghost"
      `git config user.name`.chomp.should == "Ghost"
    end

    it "should add the author to the list in .git_tracking file" do
      config.instance_eval { @config[:authors] = ["Joe"] }
      config.author = "Steve"
      config.authors.should include("Steve")
      YAML.load_file(".git_tracking")[:authors].should include("Steve")
    end

    it "should not add the author more than once" do
      config.instance_eval { @config[:authors] = ["Joe"] }
      config.author = "Joe"
      config.authors.should == ["Joe"]
      YAML.load_file(".git_tracking")[:authors].should == ["Joe"]
    end
  end

  it "#authors should return an array of authors" do
    config.instance_eval { @config[:authors] = ["Joe", "Bob", "Steve"] }
    config.authors.should == ["Joe", "Bob", "Steve"]
  end

  describe "#last_commit_info" do
    before(:all) do
      File.rename ".git", ".git_old" if File.exists? ".git"
    end
    before(:each) do
      system "git init; git add README; git commit -m 'initial commit'"
    end
    after(:each) do
      File.delete "foo.txt" if File.exists? "foo.txt"
      system "rm -rf .git" if File.exists? ".git"
    end
    after(:all) do
      File.rename ".git_old", ".git" if File.exists? ".git_old"
    end

    it "should return info about the last commit" do
      f = File.new("foo.txt", "w") {|f| f.puts "lalala"}
      system "git add foo.txt"
      system "git commit -m 'best commit evar'"
      config.last_commit_info.should match(/\w{6,8} best commit evar/)
    end
  end

  it "#last_story_id should return the git-tracking.last-story-id from git config" do
    system "git config git-tracking.last-story-id '736741'"
    config.last_story_id.should == '736741'
  end

  it "#last_story_id= should set the git-tracking.last-story-id in git config" do
    (config.last_story_id='234900').should == '234900'
    `git config git-tracking.last-story-id`.chomp.should == '234900'
  end

  it "#last_api_key should return the git-tracking.last-api-key from git config" do
    system "git config git-tracking.last-api-key '736741'"
    config.last_api_key.should == '736741'
  end

  it "#last_api_key= should set the git-tracking.last-api-key in git config" do
    (config.last_api_key='123444').should == '123444'
    `git config git-tracking.last-api-key`.chomp.should == '123444'
  end

  it "#last_email should return the email that corresponds to the last api key used" do
    config.instance_eval do
      @config[:keys] = {
        "foo@bar.com" => "987125jf"
      }
    end
    system "git config git-tracking.last-api-key '987125jf'"
    config.last_email.should == "foo@bar.com"
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
          "foo@bar.com" => "alsdkjf91",
          "baz@bang.com" => "dsgkj39dk3"
        }
      end
      config.key_for_email("foo@bar.com").should == 'alsdkjf91'
    end

    it "should set the pivotal api key and store it" do
      config.key_for_email("foo@bar.com", 'kdslghj348')
      YAML.load_file(".git_tracking")[:keys]["foo@bar.com"].should == 'kdslghj348'
    end

    it "should set the last_api_key as well" do
      config.should_receive(:last_api_key=).with('kdslghj348').ordered
      config.should_receive(:last_api_key=).with('dsgkj39dk3').ordered
      config.key_for_email("foo@bar.com", 'kdslghj348')
      config.instance_eval do
        @config[:keys] = {
          "baz@bang.com" => "dsgkj39dk3"
        }
      end
      config.key_for_email("baz@bang.com")
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

