# File: ./lib/dami/schema/generator.rb

# frozen_string_literal: true

module Dami
  module Schema
    class Generator
      def generate(diff_result, name)
        return if diff_result[:up].empty?

        timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
        
        # "AddEmailToUsers" -> "add_email_to_users"
        snake_case_name = name.gsub(/::/, '/')
                              .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
                              .gsub(/([a-z\d])([A-Z])/,'\1_\2')
                              .tr("-", "_")
                              .downcase
        
        filename = "#{timestamp}_#{snake_case_name}.rb"
        
        migrations_dir = Dami.configuration.migrations_path
        path = File.join(migrations_dir, filename)

        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, generate_content(diff_result))
        
        path
      end

      private

      def generate_content(diff_result)
        up_content = diff_result[:up].map { |cmd| command_to_string(cmd) }.join("\n    ")
        down_content = diff_result[:down].map { |cmd| command_to_string(cmd) }.join("\n    ")

        <<~RUBY
          # This file is auto-generated. You can edit it before running migrations.

          def up
            #{up_content}
          end

          def down
            #{down_content}
          end
        RUBY
      end

      def command_to_string(cmd)
        case cmd[:command]
        when :create_table
          cols = cmd[:columns].map { |name, opts| "t.field :#{name}, :#{opts[:type]}" }.join("\n      ")
          "create_table(:#{cmd[:name]}) do |t|\n      #{cols}\n    end"
        when :drop_table
          "drop_table(:#{cmd[:name]})"
        when :add_column
          "add_column(:#{cmd[:table]}, :#{cmd[:name]}, :#{cmd[:type]})"
        when :remove_column
          "remove_column(:#{cmd[:table]}, :#{cmd[:name]})"
        when :add_index
          "add_index(:#{cmd[:table]}, :#{cmd[:column]})"
        when :remove_index
          "remove_index(:#{cmd[:table]}, :#{cmd[:column]})"
        end
      end
    end
  end
end