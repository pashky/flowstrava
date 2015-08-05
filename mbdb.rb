#!/usr/bin/env ruby
# Original source: https://github.com/kastner/ruby-junk/blob/master/mbdb_parser.rb
require 'openssl'

module SillyHasher
  extend self

  def hash(strings)
    OpenSSL::Digest::SHA1.hexdigest(join_strings(strings))
  end

  def join_strings(strings)
    strings = [strings] unless strings.respond_to?(:each)
    strings.reject {|a| a == ''}.join("-")
  end
end

class MBDBEntry
  attr_accessor :permissions, :path, :domain, :hash, :file_size, :children, :full_path
  attr_accessor :link_target, :atime, :mtime, :ctime, :flag, :dummy

  def initialize(dummy = false)
    @atime = @mtime = @ctime = Time.now
    @dummy = dummy
  end

  def directory?
    @file_size == 0 && (@permissions & 0o40000 > 0)
  end

  def copy(other)
    self.instance_variables.each do |ivar|
      next if ivar == :children
      self.send("#{ivar}=", other.send(ivar))
    end

    @dummy = false
  end

  def to_s
    self.instance_variables.map do |ivar| 
      value = self.instance_variable_get(ivar)
      value = "count: #{value.size}" if value.kind_of?(Array)
      "#{ivar} => #{value}"
    end.join(", ")
  end
end

class MBDBParser
  def self.parse(mbdb_path, &block)
    p = new(mbdb_path)

    until p.ended?
      p.extract_record(&block)
    end
  end

  def extract_record
    entry = MBDBEntry.new

    entry.domain = get_string
    entry.path = get_string
    entry.link_target = get_string

    skip_string # DataHash
    skip_string # "Unknown"

    entry.permissions = get_uint16

    skip(4 * 4) # skip 4, 32 bit entries

    entry.ctime = Time.at(get_uint32)
    entry.mtime = Time.at(get_uint32)
    entry.atime = Time.at(get_uint32)

    entry.file_size = get_uint64

    entry.flag = get_uint8

    if entry.directory?
      entry.full_path = File.join(File::SEPARATOR, entry.domain, entry.path, "")
    else
      entry.full_path = File.join(File::SEPARATOR, entry.domain, entry.path)
    end

    attribs = get_uint8 # attribute count
    attribs.times { skip_string; skip_string } if attribs

    entry.hash = SillyHasher.hash([entry.domain, entry.path])

    yield(entry) if block_given?
    entry
  end

  def initialize(mbdb_path, file_class=File, no_skip=false)
    @mbdb_file = mbdb_path
    @f = file_class.open(mbdb_path)

    # skip name / version header
    skip(6) unless no_skip
  end

  def ended?
    @f.eof?
  end

  def skip(bytes)
    @f.read(bytes)
  end

  def get_string
    len = get_uint16
    return "" if len == 0xFFFF
    # make a new string so it's UTF-8
    s = ""
    read(len, s).inspect
    return s
  end

  def skip_string
    len = get_uint16

    return if len == 0xFFFF
    skip(len)
  end

  def get_uint8;  get_uint(1, :C); end
  def get_uint16; get_uint(2, :S); end
  def get_uint32; get_uint(4, :L); end
  def get_uint64; get_uint(8, :Q); end

  def get_uint(bytes, packing)
    d = read(bytes)
    return d.reverse.unpack(packing.to_s)[0]
    # read(bytes).unpack("n")[0]
  end

  def read(bytes, string=nil)
    @f.read(bytes, string)
  end
end

