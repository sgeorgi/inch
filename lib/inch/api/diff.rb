module Inch
  module API
    # Returns a Compare::Codebases object for two revisions of the same
    # codebase
    class Diff
      attr_reader :codebase_old
      attr_reader :codebase_new
      attr_reader :comparer
      attr_reader :work_dir

      # @param dir [String] the working directory of the codebase
      # @param before_rev [String] the 'before' revision
      # @param after_rev [String,nil] the 'after' revision that the 'before'
      #   one is compared against
      def initialize(dir, before_rev, after_rev = nil)
        @work_dir = dir
        @codebase_old = codebase_for(before_rev)
        @codebase_new = if after_rev.nil?
            Codebase.parse(work_dir)
          else
            codebase_for(after_rev)
          end
        @comparer = API::Compare::Codebases.new(@codebase_old, @codebase_new)
      end

      private

      def codebase_for(revision)
        if cached = codebase_from_cache(revision)
          cached
        else
          codebase = codebase_from_copy(work_dir, revision)
          filename = Codebase::Serializer.filename(revision)
          Codebase::Serializer.save(codebase, filename)
          codebase
        end
      end

      def codebase_from_cache(revision)
        filename = Codebase::Serializer.filename(revision)
        if File.exist?(filename)
          Codebase::Serializer.load(filename)
        end
      end

      def codebase_from_copy(original_dir, revision)
        codebase = nil
        Dir.mktmpdir do |tmp_dir|
          new_dir = copy_work_dir(original_dir, tmp_dir)
          git_reset(new_dir, revision)
          codebase = Codebase.parse(new_dir)
        end
        codebase
      end

      def copy_work_dir(original_dir, tmp_dir)
        git tmp_dir, "clone #{original_dir} --quiet"
        File.join(tmp_dir, File.basename(original_dir))
      end

      def git_reset(dir, revision = nil)
        git dir, "reset --hard #{revision}"
      end

      def git(dir, command)
        old_pwd = Dir.pwd
        Dir.chdir dir
        out = `git #{command}`
        Dir.chdir old_pwd
        out
      end

    end
  end
end
