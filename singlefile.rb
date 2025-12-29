require 'bundler/setup'
require 'dotenv/load'
require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/reloader' if development?
require 'redcarpet'
require 'nokogiri'
require 'active_support/all'
require 'json'
require 'net/http'
require 'open3'
require_relative 'helpers'
require_relative 'models/conversation_thread'
require_relative 'models/message'
require_relative 'models/task'

set :database_file, 'config/database.yml'

configure :development do
  also_reload 'helpers.rb'
  also_reload 'models/*.rb'
end

helpers AppHelpers

set :host_authorization, { permitted_hosts: [] }
set :public_folder, '.'

# Slack configuration (set via environment variables)
SLACK_BOT_TOKEN = ENV['SLACK_BOT_TOKEN']
SLACK_SIGNING_SECRET = ENV['SLACK_SIGNING_SECRET']
SLACK_DEFAULT_CHANNEL = ENV['SLACK_DEFAULT_CHANNEL'] || '@tony'
API_KEY = ENV['API_KEY']

# API authentication
def require_api_key!
  provided_key = request.env['HTTP_X_API_KEY'] || params['api_key']
  halt 401, { error: 'Unauthorized' }.to_json unless provided_key == API_KEY
end

before '/tasks*' do
  require_api_key! unless request.path == '/tasks' && request.get? # Allow listing without auth for now
end

before '/threads*' do
  require_api_key!
end

before '/notify' do
  require_api_key!
end

# ===================
# Web UI Routes
# ===================

get '/' do
  content = File.read("readme.md")
  erb markdown(content), layout: :"layout.html"
end

get '/code' do
  erb :code, layout: :"layout.html"
end

# ===================
# Tasks API
# ===================

# List tasks
get '/tasks' do
  content_type :json
  tasks = Task.order(created_at: :desc).limit(50)
  tasks.to_json
end

# Create a task
post '/tasks' do
  content_type :json
  data = JSON.parse(request.body.read)

  task = Task.create!(
    thread_id: data['thread_id'],
    run_at: data['run_at'] ? Time.parse(data['run_at']) : Time.current,
    prompt: data['prompt'],
    notify: data['notify'] || 'slack',
    status: 'pending'
  )

  task.to_json
end

# Get a specific task
get '/tasks/:id' do
  content_type :json
  task = Task.find(params[:id])
  task.to_json
end

# Delete a task
delete '/tasks/:id' do
  content_type :json
  task = Task.find(params[:id])
  task.destroy
  { success: true }.to_json
end

# ===================
# Threads API
# ===================

# List threads
get '/threads' do
  content_type :json
  threads = ConversationThread.order(updated_at: :desc).limit(50)
  threads.to_json
end

# Create a thread
post '/threads' do
  content_type :json
  data = JSON.parse(request.body.read)

  thread = ConversationThread.create!(
    name: data['name'],
    session_id: data['session_id']
  )

  thread.to_json
end

# Get thread with messages
get '/threads/:id' do
  content_type :json
  thread = ConversationThread.find(params[:id])
  {
    thread: thread,
    messages: thread.messages.order(:created_at)
  }.to_json
end

# ===================
# Notifications API
# ===================

post '/notify' do
  content_type :json
  data = JSON.parse(request.body.read)

  channel = data['channel'] || SLACK_DEFAULT_CHANNEL
  message = data['message'] || data['text']

  result = send_slack_message(channel, message)
  result.to_json
end

# ===================
# Slack Events API
# ===================

# Simple deduplication cache (in-memory)
PROCESSED_MESSAGES = {}
PROCESSED_MESSAGES_MUTEX = Mutex.new

def already_processed?(event_id)
  PROCESSED_MESSAGES_MUTEX.synchronize do
    return true if PROCESSED_MESSAGES[event_id]
    PROCESSED_MESSAGES[event_id] = Time.now
    # Clean old entries (older than 5 minutes)
    PROCESSED_MESSAGES.delete_if { |_, time| Time.now - time > 300 }
    false
  end
end

post '/slack/events' do
  content_type :json
  body = request.body.read
  data = JSON.parse(body)

  # Handle URL verification challenge
  if data['type'] == 'url_verification'
    return { challenge: data['challenge'] }.to_json
  end

  # Handle events
  if data['type'] == 'event_callback'
    event = data['event']
    event_id = "#{event['channel']}-#{event['ts']}"

    # Ignore bot messages to prevent loops
    return { ok: true }.to_json if event['bot_id']

    # Ignore already processed messages (Slack retries)
    return { ok: true }.to_json if already_processed?(event_id)

    # Ignore messages with no text
    return { ok: true }.to_json if event['text'].nil? || event['text'].strip.empty?

    # Handle direct messages or mentions
    if event['type'] == 'message' || event['type'] == 'app_mention'
      handle_slack_message(event)
    end
  end

  { ok: true }.to_json
end

# ===================
# Helper Methods
# ===================

def markdown_to_slack(text)
  text
    .gsub(/\*\*(.+?)\*\*/, '*\1*')        # **bold** → *bold*
    .gsub(/(?<!\*)_(.+?)_(?!\*)/, '_\1_') # _italic_ stays the same
    .gsub(/^### (.+)$/, '*\1*')           # ### Header → *Header*
    .gsub(/^## (.+)$/, '*\1*')            # ## Header → *Header*
    .gsub(/^# (.+)$/, '*\1*')             # # Header → *Header*
    .gsub(/\[([^\]]+)\]\(([^)]+)\)/, '<\2|\1>') # [text](url) → <url|text>
end

def send_slack_message(channel, text, thread_ts: nil)
  return { error: 'No Slack token configured' } unless SLACK_BOT_TOKEN

  uri = URI('https://slack.com/api/chat.postMessage')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  body = { channel: channel, text: text }
  body[:thread_ts] = thread_ts if thread_ts

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{SLACK_BOT_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = body.to_json

  response = http.request(request)
  JSON.parse(response.body)
end

def update_slack_message(channel, timestamp, text)
  return unless SLACK_BOT_TOKEN

  uri = URI('https://slack.com/api/chat.update')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{SLACK_BOT_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = { channel: channel, ts: timestamp, text: text }.to_json

  response = http.request(request)
  JSON.parse(response.body)
end

def add_slack_reaction(channel, timestamp, emoji)
  return unless SLACK_BOT_TOKEN

  uri = URI('https://slack.com/api/reactions.add')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{SLACK_BOT_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = { channel: channel, timestamp: timestamp, name: emoji }.to_json

  http.request(request)
end

def remove_slack_reaction(channel, timestamp, emoji)
  return unless SLACK_BOT_TOKEN

  uri = URI('https://slack.com/api/reactions.remove')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{SLACK_BOT_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = { channel: channel, timestamp: timestamp, name: emoji }.to_json

  http.request(request)
end

def handle_slack_message(event)
  user_message = event['text']
  channel = event['channel']
  timestamp = event['ts']
  # Use existing thread_ts if in a thread, otherwise use this message's ts to start a new thread
  thread_ts = event['thread_ts'] || timestamp

  # Add "eyes" reaction to show we're processing
  add_slack_reaction(channel, timestamp, 'eyes')

  # Process in background thread
  Thread.new do
    begin
      # Find or create a conversation thread using the Slack thread_ts as identifier
      thread = ConversationThread.find_or_create_by(name: "slack:#{channel}:#{thread_ts}")

      # Log the incoming message
      thread.messages.create!(role: 'user', content: user_message, channel: 'slack')

      # Post initial "thinking" message
      thinking_response = send_slack_message(channel, "_Thinking..._", thread_ts: thread_ts)
      thinking_ts = thinking_response['ts']

      # Call Claude CLI with streaming
      response, session_id = call_claude_streaming(user_message, thread, channel, thinking_ts)

      # Save the session_id for future context
      thread.update!(session_id: session_id) if session_id

      # Log the response
      thread.messages.create!(role: 'assistant', content: response, channel: 'slack')

      # Remove eyes, add checkmark
      remove_slack_reaction(channel, timestamp, 'eyes')
      add_slack_reaction(channel, timestamp, 'white_check_mark')

      # Final update with complete response (convert markdown to Slack format)
      update_slack_message(channel, thinking_ts, markdown_to_slack(response))
    rescue => e
      # On error, add X reaction
      remove_slack_reaction(channel, timestamp, 'eyes')
      add_slack_reaction(channel, timestamp, 'x')
      send_slack_message(channel, "Error: #{e.message}", thread_ts: thread_ts)
    end
  end
end

def call_claude_streaming(prompt, thread, channel, message_ts)
  args = ['claude', '-p', prompt, '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions']

  if thread&.session_id
    args += ['--resume', thread.session_id]
  end

  current_status = "_Thinking..._"
  last_update = Time.now

  # Collect all output for final response
  all_output = []

  Open3.popen3(*args) do |stdin, stdout, stderr, wait_thr|
    stdin.close

    stdout.each_line do |line|
      all_output << line
      begin
        data = JSON.parse(line)

        # Update status based on what Claude is doing
        case data['type']
        when 'tool_use'
          tool_name = data['name'] || 'tool'
          current_status = "_Using #{tool_name}..._"
        when 'tool_result'
          current_status = "_Processing result..._"
        when 'assistant'
          current_status = "_Generating response..._"
        end

        # Update Slack message every 2 seconds with status
        if Time.now - last_update > 2
          update_slack_message(channel, message_ts, current_status)
          last_update = Time.now
        end

      rescue JSON::ParserError
        # Skip malformed JSON lines
      end
    end

    wait_thr.value
  end

  # Extract final text response and session_id from the collected output
  final_response = ""
  session_id = nil
  all_output.each do |line|
    begin
      data = JSON.parse(line)
      if data['type'] == 'result'
        final_response = data['result'] if data['result']
        session_id = data['session_id'] if data['session_id']
      end
    rescue JSON::ParserError
    end
  end

  [final_response.empty? ? "No response generated" : final_response, session_id]
end