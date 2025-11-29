require 'rails_helper'

RSpec.describe An::Body, type: :model do
  describe 'associations ' do
    it { should belong_to(:an_body_type).class_name('An::BodyType') }
    it { should belong_to(:parent).class_name('An::Body').optional }
    it { should have_many(:children).class_name('An::Body').with_foreign_key(:parent_id).dependent(:destroy) }
    it { should have_many(:an_terms).class_name('An::Term').with_foreign_key(:an_body_id).dependent(:destroy) }
    it { should have_many(:constituency_terms).class_name('An::Term').with_foreign_key(:constituency_id).dependent(:destroy) }
    it { should have_and_belong_to_many(:an_countries).class_name('An::Country') }
    it { should have_many(:corrections).class_name('An::Correction').dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:an_body) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:an_body_type_id) }
  end
end
