#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple static analysis for Ruby chess engine
# This is a basic alternative to RuboCop for when bundler is not available

require 'find'

class SimpleRubyAnalyzer
  ISSUES = []
  
  def self.analyze_directory(path)
    Find.find(path) do |file|
      next unless file.end_with?('.rb')
      
      analyze_file(file)
    end
    
    report_results
  end
  
  def self.analyze_file(file)
    content = File.read(file)
    lines = content.lines
    
    lines.each_with_index do |line, index|
      line_number = index + 1
      
      # Check for long lines
      if line.length > 120
        ISSUES << "#{file}:#{line_number}: Line too long (#{line.length} > 120 characters)"
      end
      
      # Check for trailing whitespace
      if line.end_with?(' ', "\t")
        ISSUES << "#{file}:#{line_number}: Trailing whitespace"
      end
      
      # Check for missing frozen_string_literal
      if line_number == 1 && !content.include?('frozen_string_literal')
        ISSUES << "#{file}:1: Missing frozen_string_literal comment"
      end
      
      # Check for empty lines at end of file
      if line_number == lines.length && line.strip.empty?
        ISSUES << "#{file}:#{line_number}: Extra blank line at end of file"
      end
    end
  end
  
  def self.report_results
    if ISSUES.empty?
      puts "✅ No issues found! Code looks clean."
      puts "📊 Analysis complete - #{count_ruby_files} Ruby files checked"
    else
      puts "❌ Found #{ISSUES.length} issues:"
      ISSUES.each { |issue| puts issue }
      puts "\n📊 Analysis complete - #{count_ruby_files} Ruby files checked"
    end
  end
  
  def self.count_ruby_files
    count = 0
    Find.find('.') { |file| count += 1 if file.end_with?('.rb') }
    count
  end
end

if __FILE__ == $PROGRAM_NAME
  puts "🔍 Running Ruby static analysis..."
  puts "=" * 50
  SimpleRubyAnalyzer.analyze_directory('.')
end