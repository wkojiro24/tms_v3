class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: {
    staff: "staff",
    admin: "admin"
  }, _suffix: true

  validates :role, presence: true

  def display_name
    full_name = respond_to?(:full_name) ? self.full_name : nil
    full_name.present? ? full_name : email
  end
end
