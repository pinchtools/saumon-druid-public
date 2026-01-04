# frozen_string_literal: true

module An::Term::QueryActions
  extend ActiveSupport::Concern

  included do
    scope :by_capacity, ->(capacity) { where(capacity: capacity) }
  end
end
