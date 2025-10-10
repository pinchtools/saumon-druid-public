require 'rails_helper'

RSpec.describe An::Country, type: :model do
  describe 'validations' do
    subject { create(:an_country) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:insee_code) }
    it { should validate_uniqueness_of(:insee_code) }
    it { should validate_presence_of(:iso_code) }
    it { should validate_uniqueness_of(:iso_code) }
  end
end
