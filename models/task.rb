class Task < ActiveRecord::Base
  belongs_to :conversation_thread, foreign_key: 'thread_id', optional: true

  validates :prompt, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed] }
  validates :notify, inclusion: { in: %w[slack none] }

  scope :pending, -> { where(status: 'pending') }
  scope :due, -> { where('run_at <= ?', Time.current) }
  scope :ready, -> { pending.due }
end
