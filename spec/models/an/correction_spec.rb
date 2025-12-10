require 'rails_helper'

RSpec.describe An::Correction, type: :model do
  describe 'associations' do
    it { should belong_to(:correctable) }
  end

  describe 'validations' do
    subject { build(:an_correction) }

    it { should validate_presence_of(:correction_changes) }
    it { should validate_presence_of(:reason) }
    it { should validate_presence_of(:correction_type) }
    it { should validate_presence_of(:correctable) }

    let(:stakeholder) { create(:an_stakeholder) }
    let(:correction) { build(:an_correction, correctable: stakeholder, correction_changes: correction_changes) }

    context 'when correction changes contain invalid fields' do
      let(:correction_changes) { { 'nonexistent_field' => { 'before' => nil, 'after' => 'value' } } }
      before { correction.valid? }

      it { expect(correction).not_to be_valid }
      it { expect(correction.errors[:correction_changes]).to include(/does not exist on An::Stakeholder/) }
    end

    context 'when correction changes is not a hash' do
      let(:correction_changes) { 'not a hash' }
      before { correction.valid? }

      it { expect(correction).not_to be_valid }
      it { expect(correction.errors[:correction_changes]).to include(/can't be blank/) }
    end

    context 'when a valid correction field is not a hash' do
      let(:correction_changes) { { 'occupation' => 'not a hash' } }
      before { correction.valid? }

      it { expect(correction).not_to be_valid }
      it { expect(correction.errors[:correction_changes]).to include(/must be a hash/) }
    end

    context 'when a valid correction field does not have a before key' do
      let(:correction_changes) { { 'occupation' => { 'after' => 'value' } } }
      before { correction.valid? }

      it { expect(correction).not_to be_valid }
      it { expect(correction.errors[:correction_changes]).to include(/must have a 'before' key/) }
    end

    context 'when a valid correction field does not have an after key' do
      let(:correction_changes) { { 'occupation' => { 'before' => 'value' } } }
      before { correction.valid? }

      it { expect(correction).not_to be_valid }
      it { expect(correction.errors[:correction_changes]).to include(/must have an 'after' key/) }
    end
  end

  describe 'callbacks' do
    describe 'before_validation :normalize_changes_keys' do
      let(:correction) do
        build(:an_correction, correction_changes: {
          field: { before: 'old', after: 'new', api_value: 'old' }
        })
      end
      before { correction.valid? }

      it { expect(correction.correction_changes.keys).to all(be_a(String)) }
      it { expect(correction.correction_changes['field'].keys).to all(be_a(String)) }
    end

    describe 'after_create :apply_to_correctable' do
      let(:stakeholder) { create(:an_stakeholder, last_name: 'OLD') }
      let(:correction_changes) { { 'last_name' => { 'before' => 'OLD', 'after' => 'NEW' } } }

      it 'applies the correction to the correctable record' do
        expect {
          create(:an_correction, correctable: stakeholder, correction_changes: correction_changes)
        }.to change { stakeholder.reload.last_name }.from('OLD').to('NEW')
      end

      it 'handles invalid field names gracefully' do
        expect {
          create(:an_correction,
            correctable: stakeholder,
            correction_changes: { 'nonexistent' => { 'before' => nil, 'after' => 'value' } }
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
