class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :session_id
  attribute :request_id
  attribute :job_id

  def self.with_session(id = nil)
    self.session_id = id || SecureRandom.uuid
    yield
  ensure
    self.session_id = nil
  end
end
