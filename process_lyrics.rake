require "active_support/all"
require "action_view"
require "colorize"
require 'pathname'

def strip_html(line)
  sanitized = ActionView::Base.full_sanitizer.sanitize(line.strip)
end

def clean_profanity(line)
  ProfanityFilter::Base.clean(line)
end

def select_bad_words(line)
  line.split(" ").select do |word|
    ProfanityFilter::Base.profane?(word)
  end
end

def count_bad_words(line)
  select_bad_words(line).count
end

def annotate_line(line)
  line_len = line.length

  if line_len > 40
    star = "* "
  else
    star = ""
  end

  annotated_line = "#{star}#{line_len} #{line}"

  if block_given?
    yield(line_len)
  end

  return [annotated_line, line_len]
end

namespace :jsi do
  namespace :lyrics do
    desc "Removes all cleaned songs"
    task :flush do
      folder = Rails.root.join("lib/songs_import/lyrics")
      puts `rm #{folder}/*.jsi`
    end
  end
end

# A rake task to process and clean lyrics from HTML
namespace :jsi do
  namespace :lyrics do

    desc "Cleans HTML and bad words from songs"
    task :sanitize do
      THRESHOLD                  = 40
      songs_over_threshold       = 0
      average_line_length        = 0
      total_line_length          = 0
      total_lines                = 0
      total_lines_over_threshold = 0
      total_songs                = 0
      total_bad_words            = 0

      puts "\nProcessing Songs:".colorize(:green)

      # For each file in lyrics
      Dir[Rails.root.join("lib/songs_import/lyrics/**/*.txt")].each do |pathname|
        output           = ""
        annotated_output = ""
        line_lengths     = []
        total_songs      += 1

        # Open that lyrics file and parse each line:
        File.open(pathname, encoding: "windows-1252:utf-8").each_line do |line|
          clean_line               = strip_html(line)
          total_bad_words          += count_bad_words(line)
          clean_line               = clean_profanity(clean_line)
          annotated_line, line_len = annotate_line(clean_line)
          line_lengths << line_len

          total_lines_over_threshold += 1 if line_len > THRESHOLD
          total_line_length          += line_len
          total_lines                += 1

          output << clean_line + "\n"
          annotated_output << annotated_line
        end

        output.strip!

        max_len                 = line_lengths.max
        has_line_over_threshold = max_len > THRESHOLD

        songs_over_threshold    += 1 if has_line_over_threshold

        color            = has_line_over_threshold ? :red : :green
        long_lines_count = line_lengths.compact.count { |item| item > THRESHOLD }
        full_path        = Pathname.new(pathname)
        percent_over     = 100 * (long_lines_count.to_f / line_lengths.count.to_f)

        print "Sanitized: ".colorize(:green) << "#{full_path.basename}" \
        << " # of lines: #{line_lengths.length}".colorize(:green) \
        << " #{long_lines_count} lines over #{THRESHOLD} chars long |#{"%2.1f" % percent_over} %|".colorize(:yellow) \
        << " (Max: #{max_len})\n".colorize(color)

        File.open(pathname.gsub('.txt', '') + "_cleaned.jsi", "wb") do |cleaned_file|
          cleaned_file.write(output)
        end

        File.open(pathname.gsub('.txt', '') + "_annotated_#{max_len}.jsi", "wb") do |annotated_file|
          annotated_file.write(annotated_output)
        end
      end

      puts "\nProcessed #{total_songs} lyrics files".colorize(:green)
      puts "Average characters per line: #{ "%2.1f" % (total_line_length.to_f/total_lines.to_f)}".colorize(:green)
      puts "Average lines per song: #{ "%2.1f" % (total_lines.to_f/total_songs.to_f)}".colorize(:green)
      puts "Number of songs wih a line over #{THRESHOLD} characters: #{songs_over_threshold}".colorize(:green)
      puts "Number of lines longer than #{THRESHOLD} characters: #{total_lines_over_threshold}".colorize(:green)
      puts "Total number of lines processed: #{total_lines}".colorize(:green)
      puts "Total number of characters processed: #{total_line_length}".colorize(:green)
      puts "Total number of bad words: #{total_bad_words}".colorize(:green)


      print "-----------------------------------------------".colorize(:green)
      puts "\nDone!".colorize(:green)
      puts "-----------------------------------------------".colorize(:green)
    end
  end
end
