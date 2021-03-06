module Inch
  module CLI
    module Command
      module Output
        class Inspect < Base
          attr_reader :objects

          COLOR = :color198     # magenta-ish
          BG_COLOR = :color207  # magenta-ish
          LJUST = 20

          def initialize(options, objects)
            @options = options
            @objects = objects

            display_objects
          end

          private

          def display_objects
            objects.each do |o|
              print_object(o)
            end
          end

          def print_object(o)
            ui.trace
            ui.header(o.fullname, COLOR, BG_COLOR)

            print_file_info(o, COLOR)
            print_code_info(o)
            print_namespace_info(o)
            print_roles_info(o)

            print_score_summary(o)
          end

          def print_score_summary(o)
            min = o.evaluation.min_score
            max = o.evaluation.max_score
            echo "Score (min: #{min}, max: #{max})".ljust(40) +
                  "#{o.score}".rjust(5) + "#{o.priority.to_i}".rjust(4)
            echo
          end

          def print_code_info(o)
            if o.method?
              CommentAndAbbrevSource.new(o).lines.each do |line|
                echo line.gsub(/\n$/m, '').dark
              end
              echo separator
            end
          end

          def print_roles_info(o)
            if o.roles.empty?
              echo "No roles assigned.".dark
            else
              o.roles.each do |role|
                print_role_info(role)
              end
            end
            echo separator
          end

          def print_role_info(role)
            name = role.class.to_s.split('::Role::').last
            score = colored_role_score(role)

            priority = role.priority.to_s.rjust(4)
            if role.priority == 0
              priority = priority.dark
            end

            echo name.ljust(40) + score + priority
            print_min_max_score(role)
          end

          def print_min_max_score(role)
            if role.max_score
              echo "  (set max score to #{role.max_score})"
            elsif role.min_score
              echo "  (set min score to #{role.min_score})"
            end
          end

          def print_namespace_info(o)
            if o.namespace?
              echo "Children:"
              o.children.each do |child|
                echo "+ " + child.fullname.color(COLOR)
              end
              echo separator
            end
          end

          def colored_role_score(role)
            if role.potential_score
              "(#{role.potential_score})".rjust(5).yellow.dark
            else
              value = role.score
              colored_score value, value.abs.to_s.rjust(4)
            end
          end

          def colored_score(value, score)
            if value < 0
              ("-" + score).red
            elsif value > 0
              ("+" + score).green
            else
              " " + score
            end
          end

          def echo(msg = "")
            ui.edged(COLOR, msg)
          end

          def separator
            "-".color(COLOR) * (CLI::COLUMNS - 2)
          end

          class CommentAndAbbrevSource < Struct.new(:code_object)
            extend Forwardable

            def_delegators :code_object, :source, :files

            def lines
              to_s.lines
            end

            def to_s
              comments.join('') + abbrev_source
            end

            private

            def abbrev_source
              lines = code_object.source.to_s.lines.to_a
              if lines.size >= 5
                indent = lines[1].scan(/^(\s+)/).flatten.join('')
                lines = lines[0..1] +
                        ["#{indent}# ... snip ...\n"] +
                        lines[-2..-1]
              end
              lines.join('')
            end

            def comments
              @comments ||= code_object.files.map do |declaration|
                get_lines_up_while(declaration.filename, declaration.line_no - 1) do |line|
                  line =~ /^\s*#/
                end.flatten.join('')
              end
            end

            def get_lines_up_while(filename, line_no, &block)
              lines = []
              line = get_line_no(filename, line_no)
              if yield(line) && line_no > 0
                lines << line.gsub(/^(\s+)/, '')
                lines << get_lines_up_while(filename, line_no - 1, &block)
              end
              lines.reverse
            end

            # Returns a +line_number+ from a file
            #
            # @param filename [String]
            # @param line_number [Fixnum]
            # @return [String]
            def get_line_no(filename, line_number)
              f = File.open(filename)
              line_number.times{f.gets}
              result = $_
              f.close
              result
            end
          end
        end
      end
    end
  end
end
