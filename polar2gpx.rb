#!/usr/bin/env ruby
require 'rubygems'
require 'builder'
require 'date'
require "sqlite3"
require './route'
require './mbdb'

date = ARGV[0]

Dir[ENV['HOME'] + "/Library/Application Support/MobileSync/Backup/*"].each do |backup|
  puts "using backup #{backup}"
  MBDBParser.parse(backup + '/Manifest.mbdb') do |entry|
    if entry.path.end_with? "PEDataModel.sqlite"
      file = backup + '/' + entry.hash
      if File.exists?(file)
        puts "using database #{file}"
        db = SQLite3::Database.new file
        db.execute("select ZPROTODATA,ZUNIQUETRAININGCOMPUTERPATH from ZPESYNCABLEENTITY where ZUNIQUETRAININGCOMPUTERPATH like '/U/0/#{date}/E/%/ROUTE.GZB'") do |row|
          db.execute("select ZBINARYDATA from ZPEPROTODATA where Z_PK = ?", row[0]) do |data|
            r = Route.decode(data[0])
            fields = ["latitude", "longitude", "altitude", "duration"]
            points = fields.map{|k| r[k]}.transpose.map {|d| Hash[*fields.zip(d).flatten]}

            time = DateTime.new(r.timestamp.date.year, r.timestamp.date.month, r.timestamp.date.day,
                                r.timestamp.time.hour, r.timestamp.time.minute, r.timestamp.time.seconds).to_time

            puts "exporting #{time.to_s}"
            name = "Polar " + time.to_s
            
            xml = Builder::XmlMarkup.new(:target => File.open(name + ".gpx", "w"), :ident => 2)
            xml.instruct!
            xml.gpx(:xmlns => "http://www.topografix.com/GPX/1/1") do
              xml.trk do
                xml.name(name)
                xml.trkseg do 
                  points.each do |p|
                    xml.trkpt(:lat => p['latitude'], :lon => p['longitude']) do
                      xml.ele(p['altitude'])
                      seconds = p['duration']/1000
                      xml.time((time + seconds).to_datetime.to_s)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end  
end
