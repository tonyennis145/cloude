class Message < ActiveRecord::Base
  belongs_to :conversation_thread, foreign_key: 'thread_id', optional: true

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
end
