require 'sinatra'
require_relative "./database"

set :bind, '0.0.0.0'
set :port, ENV.fetch("PORT")
set :environment, :production unless ENV["DEVELOPMENT"] == true

def time_diff(seconds_diff)
  seconds_diff = seconds_diff.to_i

  hours = seconds_diff / 3600
  seconds_diff -= hours * 3600

  minutes = seconds_diff / 60
  seconds_diff -= minutes * 60

  if hours > 0
    return "#{hours}h"
  elsif minutes > 20
    return "#{minutes}m"
  else
    return "Just now"
  end
end

get '/stories.json' do
  output = []
  user_id = params.fetch(:user_id)
  Database.database[:stories].where(user_id: user_id).each do |story|
    relative_diff_in_seconds = (Time.now - Time.at(story[:timestamp]))
    relative_diff_in_h = relative_diff_in_seconds / 60 / 60
    next if relative_diff_in_h > 24 # only show the most recent stories

    formatted_time_diff = time_diff(relative_diff_in_seconds)

    output << {
      signed_url: story[:signed_url],
      timestamp: story[:timestamp],
      is_video: story[:is_video],
      caption: story[:caption],
      permalink: story[:permalink],
      relative_diff_in_h: relative_diff_in_h,
      formatted_time_diff: formatted_time_diff,
      user_id: user_id,
    }
  end

  date = Date.today
  existing_entry = Database.database[:views].where(date: date, user_id: user_id)
  if existing_entry.count == 0
    Database.database[:views].insert({
      date: date,
      count: 0,
      prefetches: 0,
      user_id: user_id
    })
    existing_entry = Database.database[:views].where(date: date, user_id: user_id)
  end

  existing_entry.update(
    count: existing_entry.first[:count],
    prefetches: existing_entry.first[:prefetches] + 1
  )

  headers('Access-Control-Allow-Origin' => "*")
  content_type('application/json')

  output.to_json
end

get "/didOpenStories" do
  date = Date.today
  user_id = params.fetch(:user_id)

  headers('Access-Control-Allow-Origin' => "*")

  existing_entry = Database.database[:views].where(date: date, user_id: user_id)
  existing_entry.update(count: existing_entry.first[:count] + 1)

  "Success"
end
