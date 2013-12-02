require_relative "lyrics"

namespace :jsi do
  namespace :songs do

    # Processes CSV file for lyrics The columns of the CSV file must match the column names
    # of the songs table in the database
    desc "Import song files"
    task load: :environment do
      ActiveRecord::Base.logger = nil

      # For each Lyrics CSV file
      Dir.glob("lib/songs_import/csv/*.csv").each do |csv_filename|
        csv_path = Pathname.new(csv_filename)
        tier_name = csv_path.basename.sub_ext('').to_s

        lyrics_directory = csv_path.parent.dirname.to_s + "/lyrics/" + tier_name

        puts "\n---------------------------------------------------------------"
        puts "  ** Processing: #{lyrics_directory} **"
        puts "---------------------------------------------------------------\n"

        # Process files in that directory
        JSI::Lyrics.clean_all(lyrics_directory)
        JSI::Lyrics.process_csv(csv_filename, lyrics_directory)

        puts "\n---------------------------------------------------------------"
        puts "  ** FINISHED PROCESSING: #{lyrics_directory} **"
        puts "---------------------------------------------------------------\n"
      end
    end
  end
end
