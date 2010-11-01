require 'git_tracking'
require 'ruby-debug'

describe GitTracking do
  before(:all) do
    File.rename ".git", ".git_old" if File.exists? ".git"
  end

  before(:each) do
    do_cmd "rm -rf .git" if File.exists? ".git"
    do_cmd "git init; git add README; git commit -m 'initial commit'"
  end

  after(:all) do
    do_cmd "rm -rf .git" if File.exists? ".git"
    File.rename ".git_old", ".git" if File.exists? ".git_old"
  end

  it ".pre_commit should call detect_debuggers and detect_incomplete_merges" do
    GitTracking.should_receive(:detect_debuggers)
    GitTracking.should_receive(:detect_incomplete_merges)
    GitTracking.pre_commit
  end

  describe ".detect_debuggers" do
    context "configured to reject commits with debuggers" do
      it "should detect debuggers and raise DebuggerException" do
        GitTracking.config.stub(:raise_on_debugger).and_return(true)
        make_foo_file "debugger"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say").with("foo.txt:debugger")
        lambda{GitTracking.detect_debuggers}.should raise_error(DebuggerException, "Please remove debuggers prior to committing")
      end
    end

    context "configured to simply warn about commits with debuggers" do
      it "should detect debuggers" do
        GitTracking.config.stub(:raise_on_debugger).and_return(false)
        make_foo_file "debugger"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say").with("foo.txt:debugger")
        lambda{GitTracking.detect_debuggers}.should_not raise_error
      end
    end
  end

  describe ".detect_incomplete_merges" do
    context "configured to reject commits with incomplete merges" do
      it "should detect incomplete merges and raise IncompleteMergeException" do
        GitTracking.config.stub(:raise_on_incomplete_merge).and_return(true)
        make_foo_file "<<<<<<<", "your changes", "=======", "my changes", ">>>>>>>"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say").with("foo.txt:<<<<<<<\nfoo.txt:>>>>>>>")
        lambda{GitTracking.detect_incomplete_merges}.should raise_error(IncompleteMergeException, "Please complete your merge prior to committing")
      end
    end

    context "configured to simply warn about commits with incomplete merges" do
      it "should detect incomplete merges and raise IncompleteMergeException" do
        GitTracking.config.stub(:raise_on_incomplete_merge).and_return(false)
        make_foo_file "<<<<<<<", "your changes", "=======", "my changes", ">>>>>>>"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say").with("foo.txt:<<<<<<<\nfoo.txt:>>>>>>>")
        lambda{GitTracking.detect_incomplete_merges}.should_not raise_error(IncompleteMergeException, "Please complete your merge prior to committing")
      end
    end
  end

  describe "#story" do
    it "should require a story"
    context "the branch name has a valid story id" do
      it "should output the story name"
    end
    it "should remember the last story id used"
    it "should prompt for an alternate story id"
  end
  it "should output the current git author"
  it "should prompt for an alternate git author"
end

def make_foo_file(*content)
  f = File.new("foo.txt", "w")
  f.puts *content
  f.close
end

def do_cmd(command)
  orig_stdout = $stdout

  # redirect stdout to /dev/null
  $stdout = File.new('/dev/null', 'w')
  system command
ensure
  # restore stdout
  $stdout = orig_stdout
end
