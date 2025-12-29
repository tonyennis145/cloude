require 'sinatra/activerecord/rake'
require './singlefile'

namespace :tasks do
  desc "Run all pending scheduled tasks that are due"
  task :run do
    puts "Checking for due tasks at #{Time.current}..."

    Task.ready.find_each do |task|
      puts "Running task ##{task.id}: #{task.prompt.truncate(50)}"
      task.update!(status: 'running')

      begin
        response = call_claude(task.prompt, task.conversation_thread)
        task.update!(status: 'completed', result: response)

        # Log to thread if present
        if task.conversation_thread
          task.conversation_thread.messages.create!(
            role: 'user', content: task.prompt, channel: 'scheduled'
          )
          task.conversation_thread.messages.create!(
            role: 'assistant', content: response, channel: 'scheduled'
          )
        end

        # Send notification
        if task.notify == 'slack'
          send_slack_message(SLACK_DEFAULT_CHANNEL, "Scheduled task completed:\n\n#{response}")
          puts "Sent Slack notification"
        end

        puts "Task ##{task.id} completed"
      rescue => e
        task.update!(status: 'failed', result: e.message)
        puts "Task ##{task.id} failed: #{e.message}"
      end
    end

    puts "Done."
  end
end
