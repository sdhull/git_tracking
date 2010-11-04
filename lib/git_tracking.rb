this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift this_dir unless $:.include? this_dir

# stdlib
require 'ftools'

# gems
require 'highline'
require 'pivotal-tracker'

# stuff frm this library
require 'git_tracking/config'
require 'git_tracking/detect'

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

    def commit_message
      File.read(ARGV[0])
    end

    def pre_commit
      detect_debuggers
      detect_incomplete_merges
    end

    def prepare_commit_msg
      author
      original_message = commit_message
      File.open(ARGV[0], "w") do |f|
        f.puts story_info
        f.puts
        f.puts "  - #{original_message}"
      end
    end

    def pivotal_project
      return @pivotal_project if @pivotal_project
      PivotalTracker::Client.token = api_key
      @pivotal_project = PivotalTracker::Project.find(config.project_id)
    end

    def project_id
      return config.project_id if config.project_id
      id = highline.ask("Please enter the PivotalTracker project id for this project") do |q|
        q.validate = lambda do |a|
          PivotalTracker::Client.token = api_key
          PivotalTracker::Project.find(a) rescue false
        end
      end
      config.project_id(id)
    end

    def story_info
      "[##{story.id}] #{story.name}"
    end

    def story
      return @story if @story

      if story_id
        story = get_story(story_id)
        highline.say("Found a valid story id in your branch or commit: #{story.id} - #{story.name}")
        @story = highline.ask("Hit enter to confirm story id #{story.id}, or enter some other story id: ", lambda{|a| get_story(a)}) do |q|
          q.default =  story.id
          q.validate = lambda{|a| check_story_id(a)}
        end
      else
        @story = highline.ask("Please enter a valid Pivotal Tracker story id: ", lambda{|a| get_story(a)}) do |q|
          q.validate = lambda{|a| check_story_id(a)}
        end
      end
    end

    def branch
      `git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`.chomp.gsub("* ", "")
    end

    def story_id
      @story_id ||= extract_story_id(commit_message) || extract_story_id(branch) || config.git[:last_story_id]
    end

    def extract_story_id(string)
      the_story_id = string.match(/\d{5,}/)[0] if string.match(/\d{5,}/)
      return the_story_id if check_story_id(the_story_id)
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
      message, retry_count = nil, 0
      email = highline.choose(config.emails) do |menu|
        menu.choice("Enter new") { highline.ask("New Email: ") }
      end
      config.add_email(email)
      unless @api_key = config.key_for_email(email)
        begin
          highline.say message if message
          password = highline.ask("Enter your PivotalTracker password: ") {|q| q.echo "x" }
          @api_key = PivotalTracker::Client.token(email, password)
          config.key_for_email(email, @api_key)
        rescue RestClient::Request::Unauthorized
          retry_count += 1
          message = "401 Unauthorized. Please try again."
          if retry_count < 3
            retry
          else
            highline.say("Unable to authenticate to Pivotal Tracker. Exiting...")
            raise RestClient::Request::Unauthorized
          end
        end
      end

      @api_key
    end

    def check_story_id(id)
      return true if get_story(id)
    end

    def get_story(id)
      pivotal_project.stories.find(id)
    end
  end
end
