#!/usr/bin/env ruby

# Copyright (c) Klaus Kämpf 2021
#
# Licensed under the MIT License

# hxc_repair_xml <hxc.xml>
#
# Repairs missing sectors in an HxC XML dump
# writes fixed XML to stdout

require 'nokogiri'

def help message=nil
  STDERR.puts "Err: #{message}" if message
  STDERR.puts "Usage:"
  STDERR.puts "  repair_xml <hxc.xml>"
  STDERR.puts "\trepairs missing sectors in HxC XML dumps"
  exit ((message)?1:0)
end

def expect what, value1, how, value2
  case how
  when :eq
    unless value1 == value2
      case value1
      when Integer
        STDERR.puts "Expectation fails: #{what}: 0x#{value1.to_s(16)} == 0x#{value2.to_s(16)} -> false"
      else
        STDERR.puts "Expectation fails: #{what}: #{value1.inspect} == #{value2.inspect} -> false"
      end
      exit(1)
    end
  else
  end
end

# check <track_list> / <sector_list> for missing sectors:
# - number_of_tracks * number_of_sides * sector_per_track
#   check if all sectors present
#     if sector missing
#       insert new (empty) sector
# - id is missing
# - sector_size from <layout>
# - <datamark> from previous sector

def repair name
  unless File.readable?(name)
    help "File not readable: #{name}"
  end
  unless File.file?(name)
    help "Not a plain file: #{name}"
  end
  doc = File.open(name) { |f| Nokogiri::XML f }
  # <disk_layout>
  #   <disk_layout_name>AUTOGENERATEDLAYOUT</disk_layout_name>
  #   <disk_layout_description>Auto Generated Disk Layout</disk_layout_description>
  #   <prefered_file_extension>img</prefered_file_extension>
  #   <interface_mode>GENERIC_SHUGART_DD_FLOPPYMODE</interface_mode>
  #   <file_size>258944</file_size>
  #   <layout>
  #     <number_of_track>80</number_of_track>
  #     <number_of_side>1</number_of_side>
  #     <format>IBM_FM</format>
  #     <start_sector_id>1</start_sector_id>
  #     <sector_per_track>26</sector_per_track>
  #     <sector_size>128</sector_size>
  #     <formatvalue>0</formatvalue>
  #     <gap3>255</gap3>
  #     <bitrate>499733</bitrate>
  #     <pregap>0</pregap>
  #     <rpm>359</rpm>

  # extract
  # - number_of_tracks
  # - number_of_sides
  # - sector_per_track
  # - sector_size
  # from <layout>


  number_of_tracks = doc.xpath("/disk_layout/layout/number_of_track").text.to_i
  number_of_sides  = doc.xpath("/disk_layout/layout/number_of_side").text.to_i
  start_sector_id  = doc.xpath("/disk_layout/layout/start_sector_id").text.to_i
  sector_per_track = doc.xpath("/disk_layout/layout/sector_per_track").text.to_i
  sector_size      = doc.xpath("/disk_layout/layout/sector_size").text.to_i

  track_size = sector_per_track * sector_size

  STDERR.puts ("#{number_of_tracks} tracks, #{number_of_sides} sides, #{sector_per_track} sectors, starting at #{start_sector_id}, #{sector_size} bytes per sector")
  track_offset = nil
  sector_offset = nil
  track_number = nil
  side_number = nil
  data_offset = nil
  added_offset = 0
  #     <track_list>
  #       <track track_number="00" side_number="0">
  #         <data_offset>0x000000</data_offset>
  #         <format>IBM_FM</format>
  #         <sector_list>
  #           <sector sector_id="1" sector_size="128">
  #             ...
  #             <datamark>0xFB</datamark>
  #             <data_offset>0x000000</data_offset>
  #           </sector>
  doc.xpath("/disk_layout/layout/track_list/track").each do |track|
    trk = track["track_number"].to_i
    expect("Track number", track_number, :eq, trk) if (track_number)
    sid = track["side_number"].to_i
    expect("Side number", side_number, :eq, sid) if (side_number)
    if (number_of_sides > 1)
      side_number = (side_number == 0) ? 1 : 0
    end
#    print "\rTrack #{trk}, Side #{sid}"
    node = track.xpath("data_offset")
    data_offset = node.text.to_i(16)
    if (added_offset > 0)
      node = track.xpath("data_offset").first
      node.content = "0x" + (node.text.to_i(16) + added_offset).to_s(16)
    end
    sector_number = nil

    track.xpath("sector_list/sector").each do |sector|
      sec = sector["sector_id"].to_i
      sector_offset = sector.xpath("data_offset").first
      data_offset = sector_offset.text.to_i(16)
      while (sector_number && (sector_number < sec)) # missing sector(s) ?
        STDERR.puts "Adding sector #{sector_number} in track #{track_number}"
        #  <sector sector_id="5" sector_size="128">
        #    <data_fill>0x00</data_fill>
        #    <datamark>0xFB</datamark>
        #    <data_offset>0x033500</data_offset>
        #  </sector>
        added = Nokogiri::XML::Node.new("sector", doc)
        added["sector_id"] = sector_number.to_s
        added["sector_size"] = sector_size.to_s
        data_fill = Nokogiri::XML::Node.new("data_fill", doc)
        data_fill.content = "0x00"
        added.add_child data_fill
        datamark = Nokogiri::XML::Node.new("datamark", doc)
        datamark.content = "0xFB" # fixme
        added.add_child datamark
        offset = Nokogiri::XML::Node.new("data_offset", doc)
        offset.content = "0x" + data_offset.to_s(16)
        added.add_child offset
        sector.add_previous_sibling added # fixme multiple -> next
        sector_number += 1
        added_offset += sector_size
      end
      if (added_offset > 0)
        sector_offset.content = "0x" + (data_offset + added_offset).to_s(16)
      end
      expect("Sector number", sector_number, :eq, sec) if sector_number
      sector_number = sec + 1
    end
    track_number = trk + 1 #fixme double sided
  end
  puts doc.to_xml
end

STDERR.puts "Repair HxC XML"

if ARGV.empty?
  help "Filename missing"
end

name = ARGV.shift
repair name