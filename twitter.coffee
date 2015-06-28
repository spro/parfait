Twitter = require 'twit'
config = require './config'
somata = require 'somata'

twitter = new Twitter config.twitter

track_keywords = ['tryna', 'javascript']
stream = twitter.stream 'statuses/filter',
    track: track_keywords.join(',')
    language: 'en'

twitter_service = new somata.Service 'twitter'
publishTweet = (tweet) ->
    twitter_service.publish 'tweet', tweet

stream.on 'tweet', publishTweet
