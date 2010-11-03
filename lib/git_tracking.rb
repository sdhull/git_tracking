$:.unshift File.expand_path(".", "lib")
$:.unshift File.expand_path(".", "lib/git_tracking")
require 'ftools'
require 'highline'
require 'pivotal-tracker'
require 'config'
require 'detect'

class PreCommitException < Exception; end
class DebuggerException < PreCommitException; end
class IncompleteMergeException < PreCommitException; end

class GitTracking
  class << self
    def highline
      @highline ||= HighLine.new
    end

    def config
      @config ||= Config.new
    end

    def pivotal_project
      return @pivotal_project if @pivotal_project
      PivotalTracker::Client.token = api_key
      PivotalTracker::Project.find(234)
    end

    def pre_commit
      detect_debuggers
      detect_incomplete_merges
    end

    def prepare_commit_msg
      commit_message = File.read(ARGV[0])
      File.open("foo.txt", "w") do |f|
        f.puts story_info
        f.puts
        f.puts "  - #{commit_message}"
      end
    end

    def story_info
      "[##{story.id}] #{story.name}"
    end

    def story
      if @story
        highline.say("Found a valid story id in your branch or commit: #{@story.id} - #{@story.name}")
        @story = highline.ask("Hit enter to confirm story id #{@story.id}, or enter some other story id: ", lambda{|a| get_story(a)}) do |q|
          q.validate(lambda{|a| check_story_id(a)})
        end
      else
        @story = highline.ask("Please enter a valid Pivotal Tracker story id: ", lambda{|a| get_story(a)}) do |q|
          q.validate(lambda{|a| check_story_id(a)})
        end
      end
    end

    def author
      if @author || (@author = `git config --global user.name`.chomp) != ""
        highline.say("git author set to: #{@author}")
        new_author = highline.ask("Hit enter to confirm author, or enter new author: ")
        @author = new_author if new_author != ""
      else
        @author = highline.ask("Please enter the git author: ")
      end
      system "git config --global user.name '#{@author}'"
      @author
    end

    def api_key
      if @api_key
        highline.say("Found a pivotal api key: #{@api_key}")
        email = highline.ask("Hit enter to use the api key 0987654567, or enter your email to change it")
        email = nil if email == ""
      end

      if @api_key.nil? || email
        email = highline.ask("Enter your PivotalTracker email: ") unless email
        password = highline.ask("Enter your PivotalTracker password: ") {|q| q.echo "x" }
        @api_key = PivotalTracker::Client.token(email, password)
      end

      @api_key
    end

    def check_story_id(id)
      return true if pivotal_project.stories.find(id)
    end

    def get_story(id)
      pivotal_project.stories.find(id)
    end
  end
end
