$:.unshift File.expand_path(".", "lib")
$:.unshift File.expand_path(".", "lib/git_tracking")
require 'ftools'
require 'highline'
require 'config'

class PreCommitException < Exception; end
class DebuggerException < PreCommitException; end
class IncompleteMergeException < PreCommitException; end

class GitTracking
  def self.highline
    @@highline ||= HighLine.new
  end

  def self.config
    @@config ||= Config.new
  end

  def self.pre_commit
    detect_debuggers
    detect_incomplete_merges
  end

  def self.detect_debuggers
    if (messages = `git grep --cached -I "debugger"`.chomp) != ""
      highline.say messages
      raise DebuggerException,
        "Please remove debuggers prior to committing" if config.raise_on_debugger
    end
  end

  def self.detect_incomplete_merges
    if (messages = `git grep --cached -I -E "^<<<<<<<|^>>>>>>>" *`.chomp) != ""
      highline.say messages
      raise IncompleteMergeException,
        "Please complete your merge prior to committing" if config.raise_on_incomplete_merge
    end
  end
end
