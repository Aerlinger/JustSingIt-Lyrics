require "active_support/all"
require "action_view"
require 'active_record'
require 'smarter_csv'
require 'colorize'
require 'pathname'

module JSI

  ##
  # = Lyrics
  #
  # Responsible for processing, cleaning, and annotating all lyrics files
  module Lyrics

    LINE_WIDTH_CUTOFF = 40

    class << self

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

      def flush()
        folder = Rails.root.join("lib/songs_import/lyrics")
        puts `rm #{folder}/*.jsi`
      end

      def clean_all(root_folder)
        songs_over_threshold       = 0
        average_line_length        = 0
        total_line_length          = 0
        total_lines                = 0
        total_lines_over_threshold = 0
        total_songs                = 0
        total_bad_words            = 0

        puts "\nProcessing Songs:".colorize(:green)

        # For each file in lyrics
        Dir[Rails.root.join(root_folder + "/**/*.txt")].each do |pathname|
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

            total_lines_over_threshold += 1 if line_len > LINE_WIDTH_CUTOFF
            total_line_length          += line_len
            total_lines                += 1

            output << clean_line + "\n"
            annotated_output << annotated_line
          end

          output.strip!

          max_len                 = line_lengths.max
          has_line_over_threshold = max_len > LINE_WIDTH_CUTOFF

          songs_over_threshold    += 1 if has_line_over_threshold

          color            = has_line_over_threshold ? :red : :green
          long_lines_count = line_lengths.compact.count { |item| item > LINE_WIDTH_CUTOFF }
          full_path        = Pathname.new(pathname)
          percent_over     = 100 * (long_lines_count.to_f / line_lengths.count.to_f)

          print "Sanitized: ".colorize(:green) << "#{full_path.basename}" \
        << " # of lines: #{line_lengths.length}".colorize(:green) \
        << " #{long_lines_count} lines over #{LINE_WIDTH_CUTOFF} chars long |#{"%2.1f" % percent_over} %|".colorize(:yellow) \
        << " (Max: #{max_len})\n".colorize(color)

          File.open(pathname.gsub('.txt', '') + "_cleaned.jsi", "wb") do |cleaned_file|
            cleaned_file.write(output)
          end

          File.open(pathname.gsub('.txt', '') + "_annotated_#{max_len}.jsi", "wb") do |annotated_file|
            annotated_file.write(annotated_output)
          end
        end
      end

      def process_csv(csv_filename, lyrics_directory)
        # Process the CSV data
        begin
          jsi_data = SmarterCSV.process(csv_filename)
        rescue Exception
          jsi_data = SmarterCSV.process(
            csv_filename,
            file_encoding: "windows-1252",
            row_sep: "\r",
            col_sep: ",",
            quote_char: "\""
          )
        end

        puts jsi_data
        puts jsi_data.first[:id]

        jsi_data.each do |song_attributes|
          lyrics_file               = Rails.root.join(lyrics_directory + "/#{song_attributes[:id]}_cleaned.jsi")
          chorus_file               = Rails.root.join(lyrics_directory + "/#{song_attributes[:id]}_chorus.jsi")

          #Rails.logger.info "Processing file: #{lyrics_file}"

          song_attributes['lyrics'] = lyrics_file.read

          begin
            song_attributes['chorus'] = chorus_file.read
          rescue Errno::ENOENT => e
            warn("Could not read chorus file: " + e.message)
          end

          begin
            song = Song.unscoped.find_or_initialize_by(
              artist: song_attributes[:artist],
              title: song_attributes[:name],
              tier: song_attributes[:tier]
            )
            song.update_attributes(song_attributes)

            if song.valid?
              Rails.logger.info "Song added to db: [#{song.id}]".colorize(:green) +
                                  "\t#{song.artist} ".colorize(:blue) +
                                  "\t#{song.name}".colorize(:magenta)
            else
              Rails.logger.error "INVALID: [#{song_attributes[:id]}] Tier: (#{song_attributes[:tier]}) #{song_attributes[:artist]}: #{song_attributes[:name]} => #{song.errors.full_messages}"
            end
          rescue Mysql2::Error => e
            puts e.message
          end
        end
      end

    end
  end
end
