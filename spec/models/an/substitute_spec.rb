require 'rails_helper'

RSpec.describe An::Substitute, type: :model do
  describe 'associations' do
    it { should belong_to(:an_term).class_name('An::Term').inverse_of(:an_substitutes) }
    it { should belong_to(:an_stakeholder).class_name('An::Stakeholder').inverse_of(:an_substitutes) }
  end

  describe 'validations' do
    it { should validate_presence_of(:an_term_id) }
    it { should validate_presence_of(:an_stakeholder_id) }
  end
end
