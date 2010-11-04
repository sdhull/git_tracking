class GitTracking
  class Config
    def initialize
      @config = {
        :raise_on_incomplete_merge => true,
        :raise_on_debugger => true,
        :emails => [],
        :keys => {}
      }
      if File.exists? ".git_tracking"
        @config.merge! YAML.load_file(".git_tracking")
      end
    end

    def raise_on_debugger
      @config[:raise_on_debugger]
    end

    def raise_on_incomplete_merge
      @config[:raise_on_incomplete_merge]
    end

    def emails
      @config[:emails]
    end

    def add_email(email)
      @config[:emails].push(email) unless emails.include?(email)
      write_to_file
    end

    def key_for_email(email, key=nil)
      return @config[:keys][email] if key.nil?
      @config[:keys][email] = key
      write_to_file
    end

    def project_id(id=nil)
      return @config[:project_id] if id.nil?
      @config[:project_id] = id
      write_to_file
      id
    end

    def write_to_file
      File.open(".git_tracking", "w") do |file|
        YAML.dump(@config, file)
      end
    end
  end
end
