class GitTracking
  class << self
    def detect_debuggers
      file_names = `git diff-index --cached -Sdebugger --name-only HEAD`
      file_names = file_names.gsub(".git_tracking",'').strip
      if file_names != ""
        highline.say highline.color("The following files have 'debugger' statements in them: ", :red)
        highline.say file_names
        raise DebuggerException,
          "Please remove debuggers prior to committing" if config.raise_on_debugger
      end
    end

    def detect_incomplete_merges
      file_names = `git diff-index --cached -S'<<<<<<<' --name-only HEAD`.chomp.split
      file_names += `git diff-index --cached -S'>>>>>>>' --name-only HEAD`.chomp.split
      file_names = file_names.uniq.join("\n")
      if file_names != ""
        highline.say highline.color("The following files have incomplete merges: ", :red)
        highline.say file_names
        raise IncompleteMergeException,
          "Please complete your merge prior to committing" if config.raise_on_incomplete_merge
      end
    end
  end
end
