require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'redcarpet'
require 'nokogiri'
require 'active_support/all'
require_relative 'helpers'

configure :development do
  also_reload 'helpers.rb'
end

helpers AppHelpers

set :host_authorization, { permitted_hosts: ['play.toniclabs.ltd'] }
set :public_folder, '.'

get '/' do
  content = File.read("readme.md")
  erb markdown(content), layout: :"layout.html"
end

get '/code' do
  erb :code, layout: :"layout.html"
end