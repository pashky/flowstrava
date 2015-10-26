#!/usr/bin/env ruby
require 'net/http'
require 'net/https'
require 'json'
require 'rubygems'
require 'bundler/setup'
require 'http-cookie'
require 'zipruby'

CONFIG = 'config.json'

config = JSON.parse(File.read(CONFIG))
jar = HTTP::CookieJar.new

uri = URI('https://flow.polar.com/')

Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
  headers = {}
  headers['Accept-Encoding'] = 'gzip, deflate'
  headers['Accept-Language'] = 'en-US,en;q=0.8,ru;q=0.6'
  headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36'
  headers['Accept'] = '*/*'

  res = http.get('/', headers)
  
  res.get_fields('set-cookie').each { |value| jar.parse(value, uri) }
  headers["Cookie"] = HTTP::Cookie.cookie_value(jar.cookies(uri))

  loginform = {
               :returnUrl => 'https://flow.polar.com/',
               :email => config['flow_email'],
               :password => config['flow_password']
              }
  res = http.post('/login', URI.encode_www_form(loginform), headers)
  
  res.get_fields('set-cookie').each { |value| jar.parse(value, uri) }
  headers["Cookie"] = HTTP::Cookie.cookie_value(jar.cookies(uri))
  
  res = http.get("/training/getCalendarEvents?start=#{config['flow_fromdate']}&end=#{config['flow_todate']}", headers)
  events = JSON.parse(res.body)
  
  exercises = events.select{|event| event["type"] == 'EXERCISE'}
  
  exercises.each do |event|
    res = http.get("#{event['url']}/export/tcx/true", headers)
    Zip::Archive.open_buffer(res.body) do |archive|
      archive.each do |entry|
        p entry.name
        open(entry.name, 'w') do |f|
          f.write(entry.read)
        end
      end
    end    
  end

  lastdate = exercises.map{|e| Time.at(e["start"])}.max
  if lastdate
    config['flow_fromdate'] = lastdate.strftime '%d.%m.%Y'
  end
  File.write(CONFIG, JSON.pretty_generate(config))
end

