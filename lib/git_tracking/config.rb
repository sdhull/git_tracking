class GitTracking
  class Config
    def initialize
      @config = {:raise_on_incomplete_merge => true, :raise_on_debugger => true}
      if File.exists? ".git_tracking.config"
        @config.merge! YAML.load_file(".git_tracking.config")
      end
    end

    def raise_on_debugger
      @config[:raise_on_debugger]
    end

    def raise_on_incomplete_merge
      @config[:raise_on_incomplete_merge]
    end
  end
end
