require 'git_tracking'
require 'ruby-debug'

describe GitTracking do
  before(:all) do
    @original_git_author = `git config --global user.name`.chomp
  end

  after(:all) do
    system "git config --global user.name '#{@original_git_author}'"
    File.delete("foo.txt") if File.exists?("foo.txt")
  end

  it ".pre_commit should call detect_debuggers and detect_incomplete_merges" do
    GitTracking.should_receive(:detect_debuggers)
    GitTracking.should_receive(:detect_incomplete_merges)
    GitTracking.pre_commit
  end

  describe ".prepare_commit_msg" do
    it "should get the message" do
      old_argv = ARGV
      File.open("foo.txt", "w") do |f|
        f.print "My awesome commit msg!"
      end
      ARGV = ["foo.txt"]
      GitTracking.stub(:story_info).and_return "[#12345] Best feature evar"
      GitTracking.stub(:author).and_return "Steve & Ghost Co-Pilot"
      GitTracking.prepare_commit_msg
      commit_msg = File.open("foo.txt", "r").read
      commit_msg.should == <<STRING
[#12345] Best feature evar

  - My awesome commit msg!
STRING
      ARGV = old_argv
    end

    it "should call story_info and author" do
      ARGV = ["foo.txt"]
      GitTracking.should_receive(:story_info).and_return "[#12345] Best feature evar"
      GitTracking.should_receive(:author)
      GitTracking.prepare_commit_msg
    end
  end

  describe ".post_commit" do
    let(:story) {mock("story")}
    let(:notes) {mock("notes")}
    before(:each) do
      GitTracking.config.stub(:last_api_key).and_return("12345")
      GitTracking.stub(:get_story).and_return(story)
      story.stub(:notes).and_return(notes)
      GitTracking.should_not_receive(:story_id) # avoid double-prompting
    end

    it "should do nothing if the story is not finished" do
      GitTracking.config.should_receive(:last_story_completed?).and_return(false)
      GitTracking.highline.should_not_receive(:ask)
      GitTracking.config.should_not_receive(:commits_for_story)
      notes.should_not_receive(:create)
      GitTracking.post_commit
    end

    it "should create a comment on the story with the commit msg and hash if the story is finished" do
      commits = <<COMMITS
commit 12345678
  - Did stuff
commit 98765456
  - Did more stuff
commit 97230182
  - Finished stuff
COMMITS
      GitTracking.config.should_receive(:last_story_completed?).and_return(true)
      GitTracking.highline.should_receive(:ask).with("Does this commit complete the story?", ["yes", "no"]).and_return("yes")
      GitTracking.config.should_receive(:commits_for_last_story).and_return(commits)
      notes.should_receive(:create).with(:text => commits)
      GitTracking.post_commit
    end

    it "should allow the user to indicate the story was not finished" do
      GitTracking.config.should_receive(:last_story_completed?).and_return(true)
      GitTracking.highline.should_receive(:ask).with("Does this commit complete the story?", ["yes", "no"]).and_return("no")
      GitTracking.config.should_not_receive(:commits_for_last_story)
      notes.should_not_receive(:create)
      GitTracking.post_commit
    end
  end

  describe ".story" do
    before do
      GitTracking.class_eval{@story = nil}
    end

    it "should require a story" do
      the_story = mock('story', :name => 'Best feature evar', :id => 12345)
      GitTracking.stub(:story_id).and_return("")
      GitTracking.stub(:get_story).and_return(nil)
      GitTracking.highline.should_receive(:ask).with("Please enter a valid Pivotal Tracker story id: ", an_instance_of(Proc)).and_return(the_story)
      GitTracking.config.should_receive(:last_story_id=).with(12345)
      GitTracking.story.should == the_story
    end

    it "should not prompt once a story has been confirmed" do
      the_story = mock('story', :name => 'Best feature evar', :id => 12345)
      GitTracking.class_eval {@story = the_story}
      GitTracking.should_not_receive(:highline)
      GitTracking.story.should == the_story
    end

    it "should allow you to enter an alternate story when it finds a story_id" do
      the_story = mock('story', :name => 'Best feature evar', :id => 85918)
      GitTracking.stub(:story_id).and_return(the_story.id)
      GitTracking.stub(:get_story).and_return(the_story)
      GitTracking.config.should_receive(:last_story_id=).with(85918)
      GitTracking.highline.should_receive(:say).
        with("Found a valid story id in your branch or commit: 85918 - Best feature evar")
      GitTracking.highline.should_receive(:ask).
        with("Hit enter to confirm story id 85918, or enter some other story id: ", an_instance_of(Proc)).
        and_return(the_story)
      GitTracking.story.should == the_story
    end
  end

  describe ".story_id" do
    before(:each) do
      GitTracking.stub(:check_story_id).and_return(true)
      GitTracking.instance_eval{@story_id = nil}
    end

    it "should check the commit message for a story id" do
      GitTracking.stub!(:commit_message).and_return("54261 - Fixing Javascript")
      GitTracking.story_id.should == '54261'
    end

    it "should check the branch name for a story id" do
      GitTracking.stub!(:commit_message).and_return("Fixing Javascript")
      GitTracking.stub!(:branch).and_return("64371-js-bug")
      GitTracking.story_id.should == '64371'
    end

    it "should check the .git/config file for the last story id" do
      GitTracking.stub!(:commit_message).and_return("Fixing Javascript")
      GitTracking.config.should_receive(:last_story_id).and_return('35236')
      GitTracking.story_id.should == '35236'
    end

    it "should verify the story_id with the pivotal tracker API" do
      GitTracking.stub!(:commit_message).and_return("Generating 55654 monkeys")
      GitTracking.stub!(:branch).and_return("64371-js-bug")
      GitTracking.should_receive(:check_story_id).with('55654').and_return(false)
      GitTracking.should_receive(:check_story_id).with('64371').and_return(true)
      GitTracking.story_id.should == "64371"
    end
  end

  describe ".extract_story_id" do
    it "should extract any number that is 5 digits or longer and return it" do
      GitTracking.stub(:check_story_id).and_return(true)
      GitTracking.extract_story_id("45674 - The best feature evar").should == "45674"
      GitTracking.extract_story_id("90873 - The best feature evar").should == "90873"
    end

    it "should return nil if there is no number that is 5 digits or longer" do
      GitTracking.stub(:check_story_id).and_return(true)
      GitTracking.extract_story_id("The best feature evar").should be_nil
    end

    it "should return nil if it's not a valid Pivotal Tracker story id" do
      GitTracking.stub(:check_story_id).and_return(false)
      GitTracking.extract_story_id("45674 - The best feature evar").should be_nil
    end
  end

  describe ".pivotal_project" do
    before(:each) { GitTracking.instance_variable_set("@pivotal_project", nil) }
    it "should get the token" do
      project = mock("project")
      PivotalTracker::Project.should_receive(:find).and_return(project)
      GitTracking.should_receive(:project_id).and_return("87655")
      GitTracking.should_receive(:api_key).and_return("alksjd9123lka")
      GitTracking.pivotal_project.should == project
    end

    it "should get and use the project_id from config" do
      project = mock("project")
      GitTracking.stub(:api_key)
      GitTracking.should_receive(:project_id).and_return(1235)
      PivotalTracker::Project.should_receive(:find).with(1235).and_return(project)
      GitTracking.pivotal_project.should == project
    end
  end

  describe ".project_id" do
    it "should prompt you to enter the project id if there is none defined" do
      GitTracking.config.stub(:project_id).ordered.and_return(nil)
      GitTracking.config.stub(:project_id).with(54876).ordered.and_return(54876)
      GitTracking.highline.should_receive(:ask).with("Please enter the PivotalTracker project id for this project").and_return(54876)
      GitTracking.project_id.should == 54876
    end

    it "should get the project id from the config" do
      GitTracking.config.should_receive(:project_id).twice.and_return(9712)
      GitTracking.project_id.should == 9712
    end
  end

  describe ".check_story_id" do
    before(:each) do
      GitTracking.stub(:api_key).and_return(5678)
    end

    it "should return true for story id that can be found in tracker" do
      PivotalTracker::Project.stub(:find).and_return(mock("project"))
      GitTracking.pivotal_project.should_receive(:stories).and_return(mock("stories", :find => mock("story")))
      GitTracking.check_story_id(5678).should be_true
    end

    it "should return false for a valid story id" do
      PivotalTracker::Project.stub(:find).and_return(mock("project"))
      GitTracking.pivotal_project.should_receive(:stories).and_return(mock("stories", :find => nil))
      GitTracking.check_story_id(5678).should be_false
    end
  end

  describe ".api_key" do
    before(:each) { GitTracking.instance_eval{ @api_key = nil} }

    it "should prompt for a pivotal login" do
      GitTracking.config.stub(:emails).and_return(["steve@home.com", "john@doe.com"])
      GitTracking.config.should_receive(:key_for_email).with("other@work.net").ordered.and_return(nil)
      GitTracking.config.should_receive(:key_for_email).with("other@work.net", "0987654567").ordered
      GitTracking.highline.should_receive(:choose).with("steve@home.com", "john@doe.com").and_return("other@work.net")
      GitTracking.highline.should_receive(:ask).with("Enter your PivotalTracker password: ").and_return("password")
      PivotalTracker::Client.should_receive(:token).with("other@work.net", "password").and_return("0987654567")
      GitTracking.api_key.should == "0987654567"
    end

    it "should prompt you to enter an alternate pivotal login" do
      GitTracking.config.stub(:emails).and_return(["steve@home.com", "john@doe.com"])
      GitTracking.config.stub(:key_for_email).and_return("8876567898")
      GitTracking.highline.should_receive(:choose).with("steve@home.com", "john@doe.com").and_return("steve@home.com")
      GitTracking.api_key.should == "8876567898"
    end

    it "should allow you to re-enter your password if authentication fails" do
      GitTracking.config.stub(:emails).and_return(["steve@home.com", "john@doe.com"])
      GitTracking.config.stub(:key_for_email).and_return(nil)
      GitTracking.highline.should_receive(:choose).and_return("other@work.net")
      GitTracking.highline.should_receive(:ask).exactly(3).times.and_return("password")
      PivotalTracker::Client.should_receive(:token).exactly(3).times.and_raise(RestClient::Request::Unauthorized)
      lambda{GitTracking.api_key}.should raise_error(RestClient::Request::Unauthorized)
    end
  end

  describe ".get_story" do
    before(:each) do
      GitTracking.stub(:api_key).and_return(5678)
    end

    it "should return true for story id that can be found in tracker" do
      story = mock("story")
      PivotalTracker::Project.stub(:find).and_return(mock("project"))
      GitTracking.pivotal_project.should_receive(:stories).and_return(mock("stories", :find => story))
      GitTracking.get_story(5678).should == story
    end

    it "should return false for a valid story id" do
      PivotalTracker::Project.stub(:find).and_return(mock("project"))
      GitTracking.pivotal_project.should_receive(:stories).and_return(mock("stories", :find => nil))
      GitTracking.get_story(5678).should be_nil
    end
  end

  it ".author should present you with an author menu" do
    GitTracking.instance_eval{ @author = nil }
    GitTracking.config.stub(:authors).and_return(["Ghost", "Steve"])
    GitTracking.highline.should_receive(:choose).with("Ghost", "Steve").and_return("Derrick")
    GitTracking.config.should_receive(:author=).with("Derrick")
    GitTracking.author.should == "Derrick"
  end

  it ".story_info should format the story info appropriately" do
    GitTracking.should_receive(:story).twice.and_return(mock("story", :name => "Best feature evar", :id => "12345"))
    GitTracking.story_info.should == "[#12345] Best feature evar"
  end
end
