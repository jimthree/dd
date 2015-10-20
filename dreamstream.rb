require 'twitter'
require 'tweetstream'
require 'mongo'
require 'awesome_print'
require 'json'

include Mongo

#&amp is being stripped out, fix.

# does this tweet match anything in the 'boring' keyword list
# This would usualy be something like song lyrics or famous sayings that include the search terms
def isBoring?(tweet) 
	@boring_json.each do |bored|
		return true if tweet.downcase.include? bored["keyphrase"].downcase
	end
	false
end

# we're not interested in retweets
def isRetweet?(tweet)
	return true if tweet[0,2] == "RT"
	false
end

# we're not interested in people despreate for retweets from celebs
def includesBlacklistedMention?(tweet)
	@blacklisted_mentions_json.each do |bm|
		return true if tweet.downcase.include? bm["name"].downcase
	end
	false
end


# find the last time of the last tweet in the DB
def getLastTweetTime()
	most_recent_t = DKDB[:dreams].find.sort(:time => -1).limit(1).first
	most_recent_time = most_recent_t["time"]
	ap "last dream captured: #{most_recent_time} - #{most_recent_t["text"]}"

end

# set up connection to the database
DKDB = Mongo::Client.new(["localhost:27017"], :database => "DreamKeeper", :user => ARGV[0], :password => ARGV[1])
# set the logger level for the mongo driver
Mongo::Logger.logger.level = ::Logger::WARN

# Pull the API keys in from the DB
keys  = DKDB[:api_keys].find.limit(1).first


# Access for the Twitter streaming client
TweetStream.configure do |config|
		config.consumer_key       = keys['config.consumer_key']
		config.consumer_secret    = keys['config.consumer_secret']
		config.oauth_token        = keys['config.oauth_token']
		config.oauth_token_secret = keys['config.oauth_token_secret']
		config.auth_method        = :oauth
end

puts "\n\n\n-----DreamStream Alpha-----\n\n\n"

# last_tweet_id = getLastTweetID()
last_tweet_time = getLastTweetTime()

# import the list of boring words and phrases
raw_boring_list = DKDB[:DKboring].find.to_a
@boring_json = JSON.parse(raw_boring_list.to_json)

# import the list of blacklisted @mentions
raw_blacklisted_menitons_list = DKDB[:blacklisted_mentions].find.to_a
@blacklisted_mentions_json = JSON.parse(raw_blacklisted_menitons_list.to_json)


# Create a tweet stream
TweetStream::Client.new.track('last night I dreamt' , 'last night I dreamed', 'had dream') do |tweet|

	if isRetweet?(tweet.text)
		puts "-RETWEET-"
	elsif isBoring?(tweet.text) 
		puts "-BORING-"
	elsif includesBlacklistedMention?(tweet.text)
		puts "-BLACKLISTED MENTION-"
	else 
		ap tweet.text
		id = DKDB[:dreams].insert_one(tweet.to_h)
		begin
			#fav = client.favorite(tweet.id)
			rescue Exception => e
			ap e
		end
	end	
end


