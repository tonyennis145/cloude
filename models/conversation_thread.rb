class ConversationThread < ActiveRecord::Base
  self.table_name = 'threads'

  has_many :messages, foreign_key: 'thread_id'
  has_many :tasks, foreign_key: 'thread_id'
end
