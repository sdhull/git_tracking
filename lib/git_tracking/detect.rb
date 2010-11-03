class GitTracking
  class << self
    def detect_debuggers
      if (messages = `git grep --cached -I "debugger"`.chomp) != ""
        highline.say messages
        raise DebuggerException,
          "Please remove debuggers prior to committing" if config.raise_on_debugger
      end
    end

    def detect_incomplete_merges
      if (messages = `git grep --cached -I -E "^<<<<<<<|^>>>>>>>" *`.chomp) != ""
        highline.say messages
        raise IncompleteMergeException,
          "Please complete your merge prior to committing" if config.raise_on_incomplete_merge
      end
    end
  end
end
