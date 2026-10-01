class User < ApplicationRecord
  has_secure_password
  has_many :todos, dependent: :destroy
  has_one :chat_memory_snapshot, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :group_chat_messages, foreign_key: :owner_id, dependent: :destroy

  validates :name, presence: true
  validates :age, presence: true
  validates :role, presence: true, inclusion: { in: %w[user admin] }
end
