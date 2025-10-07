require 'rails_helper'

RSpec.describe An::BodyType, type: :model do
  describe 'associations' do
    it { should have_many(:an_bodies).class_name('An::Body').with_foreign_key(:an_body_type_id).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
  end
end
