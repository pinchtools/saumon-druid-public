require 'rails_helper'

RSpec.describe An::Country, type: :model do
  describe 'associations' do
    it { should have_and_belong_to_many(:an_bodies).class_name('An::Body') }
  end

  describe 'validations' do
    subject { create(:an_country) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:name) }
  end
end
