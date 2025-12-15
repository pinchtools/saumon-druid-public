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

  describe 'event tracking' do
    describe 'on create' do
      let(:body_type) { create(:an_body_type) }
      let(:body) { build(:an_body, an_body_type: body_type) }

      it 'tracks a created event after commit' do
        expect { body.save! }.to change { body.events.where(action: 'created').count }.by(1)

        event = body.events.find_by(action: 'created')
        expect(event.category).to eq('data')
        expect(event.payload).to include('uid' => body.uid)
      end
    end

    describe 'on update' do
      let!(:body) { create(:an_body, label: 'Old Label') }

      it 'tracks an updated event after commit when changes are saved' do
        expect { body.update!(label: 'New Label') }.to change { body.events.where(action: 'updated').count }.by(1)

        event = body.events.find_by(action: 'updated')
        expect(event.category).to eq('data')
        expect(event.payload).to include('uuid' => body.uid)
        expect(event.payload['changes']).to include('label')
      end

      it 'does not track an event when no changes are made' do
        expect { body.save! }.not_to change { body.events.where(action: 'updated').count }
      end
    end
  end
end
