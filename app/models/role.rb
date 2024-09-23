class Role < ApplicationRecord
  include CaberSubject

  ROLES = [
    :administrator,   # Can do everything
    :moderator,       # Can edit any models
    :contributor,     # Can upload models and edit their own
    :member           # Can view models; read only access
  ]

  has_many :users, through: :users_roles

  belongs_to :resource,
    polymorphic: true,
    optional: true

  validates :resource_type,
    inclusion: {in: Rolify.resource_types},
    allow_nil: true

  validates :name,   # rubocop:todo Rails/UniqueValidationWithoutIndex
    inclusion: {in: ROLES.map(&:to_s)},
    uniqueness: true

  scopify
end
