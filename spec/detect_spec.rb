require 'lib/git_tracking'

describe GitTracking, "detect" do
  before(:all) do
    File.rename ".git_tracking", ".git_tracking.real" if File.exists?(".git_tracking")
    File.rename ".git", ".git_old" if File.exists? ".git"
  end

  before(:each) do
    do_cmd "git init; git add README; git commit -m 'initial commit'"
  end

  after(:each) do
    File.delete "foo.txt" if File.exists? "foo.txt"
    File.delete ".git_tracking" if File.exists? ".git_tracking"
    do_cmd "rm -rf .git" if File.exists? ".git"
  end

  after(:all) do
    File.rename ".git_old", ".git" if File.exists? ".git_old"
    File.rename ".git_tracking.real", ".git_tracking" if File.exists?(".git_tracking.real")
  end

  describe ".detect_debuggers" do
    context "configured to reject commits with debuggers" do
      it "should detect debuggers and raise DebuggerException" do
        GitTracking.config.stub(:raise_on_debugger).and_return(true)
        make_file "foo.txt", "debugger"
        make_file ".git_tracking", "debugger"
        do_cmd "git add foo.txt"
        do_cmd "git add .git_tracking"
        GitTracking.highline.should_receive("say")
        GitTracking.highline.should_receive("say").with("foo.txt")
        lambda{GitTracking.detect_debuggers}.should(
          raise_error(DebuggerException, "Please remove debuggers prior to committing"))
      end
    end

    context "configured to simply warn about commits with debuggers" do
      it "should detect debuggers" do
        GitTracking.config.stub(:raise_on_debugger).and_return(false)
        make_file "foo.txt", "debugger"
        make_file ".git_tracking", "debugger"
        do_cmd "git add foo.txt"
        do_cmd "git add .git_tracking"
        GitTracking.highline.should_receive("say")
        GitTracking.highline.should_receive("say").with("foo.txt")
        lambda{GitTracking.detect_debuggers}.should_not raise_error
      end
    end
  end

  describe ".detect_incomplete_merges" do
    context "configured to reject commits with incomplete merges" do
      it "should detect incomplete merges and raise IncompleteMergeException" do
        GitTracking.config.stub(:raise_on_incomplete_merge).and_return(true)
        make_file "foo.txt", "<<<<<<<", "your changes", "=======", "my changes", ">>>>>>>"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say")
        GitTracking.highline.should_receive("say").with("foo.txt")
        lambda{GitTracking.detect_incomplete_merges}.should(
          raise_error(IncompleteMergeException, "Please complete your merge prior to committing"))
      end
    end

    context "configured to simply warn about commits with incomplete merges" do
      it "should detect incomplete merges and raise IncompleteMergeException" do
        GitTracking.config.stub(:raise_on_incomplete_merge).and_return(false)
        make_file "foo.txt", "<<<<<<<", "your changes", "=======", "my changes", ">>>>>>>"
        do_cmd "git add foo.txt"
        GitTracking.highline.should_receive("say")
        GitTracking.highline.should_receive("say").with("foo.txt")
        lambda{GitTracking.detect_incomplete_merges}.should_not(
          raise_error(IncompleteMergeException, "Please complete your merge prior to committing"))
      end
    end
  end
end

def make_file(name, *content)
  f = File.new(name, "w")
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
