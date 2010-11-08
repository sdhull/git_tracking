class GitTracking
  class Config
    def initialize
      @config = {
        :raise_on_incomplete_merge => true,
        :raise_on_debugger => true,
        :authors => [],
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
      @config[:keys].keys
    end

    def last_email
      @config[:keys].invert[last_api_key]
    end

    def last_commit_info
      `git log -n 1 --oneline --abbrev-commit`
    end

    def author
      `git config user.name`.chomp
    end

    def authors
      @config[:authors]
    end

    def author=(new_author)
      @config[:authors].push(new_author).uniq!
      write_to_file
      system "git config user.name '#{new_author}'"
    end

    [:last_story_id, :last_api_key].each do |config_item|
      git_config_key = config_item.to_s.gsub("_","-")
      define_method(config_item) do
        `git config git-tracking.#{git_config_key}`.chomp
      end

      define_method("#{config_item}=") do |value|
        system "git config git-tracking.#{git_config_key} '#{value}'"
      end
    end

    def key_for_email(email, key=nil)
      return (self.last_api_key = @config[:keys][email]) if key.nil?
      self.last_api_key = key
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
