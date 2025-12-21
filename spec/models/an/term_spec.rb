require 'rails_helper'

RSpec.describe An::Term, type: :model do
  describe 'associations' do
    it { should belong_to(:an_stakeholder).class_name('An::Stakeholder') }
    it { should belong_to(:an_body).class_name('An::Body') }
    it { should belong_to(:constituency).class_name('An::Body').optional }
    it { should belong_to(:deputy_term).class_name('An::Term').optional }
    it { should have_many(:subordinate_terms).class_name('An::Term').with_foreign_key(:deputy_term_id).dependent(:destroy) }
    it { should have_many(:an_substitutes).class_name('An::Substitute').with_foreign_key(:an_term_id).inverse_of(:an_term).dependent(:destroy) }
    it { should have_one(:an_body_type).through(:an_body) }
    it { should have_many(:corrections).class_name('An::Correction').dependent(:destroy) }
  end

  describe 'scopes' do
    describe '.main' do
      let!(:main_term) { create(:an_term, :main_term) }
      let!(:non_main_term) { create(:an_term, main: false) }

      it 'returns only main terms' do
        expect(An::Term.main).to include(main_term)
        expect(An::Term.main).not_to include(non_main_term)
      end
    end

    describe '.active' do
      let!(:active_term) { create(:an_term, start_date: 1.month.ago, end_date: nil) }
      let!(:ended_term) { create(:an_term, start_date: 1.month.ago, end_date: 1.week.ago) }
      let!(:future_term) { create(:an_term, start_date: nil, end_date: nil) }

      it 'returns terms with start_date and no end_date' do
        expect(An::Term.active).to include(active_term)
        expect(An::Term.active).not_to include(ended_term)
        expect(An::Term.active).not_to include(future_term)
      end
    end

    describe '.past ' do
      let!(:past_term) { create(:an_term, start_date: 1.month.ago, end_date: 1.week.ago) }
      let!(:active_term) { create(:an_term, start_date: 1.month.ago, end_date: nil) }
      let!(:future_term) { create(:an_term, start_date: nil, end_date: nil) }

      it 'returns terms with a start and end dates' do
        expect(An::Term.past).to eq([ past_term ])
      end
    end

    describe '.by_hierarchy' do
      let!(:body_type_low) { create(:an_body_type, hierarchy_level: 1) }
      let!(:body_type_high) { create(:an_body_type, hierarchy_level: 3) }
      let!(:body_type_mid) { create(:an_body_type, hierarchy_level: 2) }

      let!(:body_low) { create(:an_body, an_body_type: body_type_low) }
      let!(:body_high) { create(:an_body, an_body_type: body_type_high) }
      let!(:body_mid) { create(:an_body, an_body_type: body_type_mid) }

      let!(:term_low) { create(:an_term, an_body: body_low) }
      let!(:term_high) { create(:an_term, an_body: body_high) }
      let!(:term_mid) { create(:an_term, an_body: body_mid) }

      it 'orders terms by hierarchy_level ascending' do
        ordered_terms = An::Term.by_hierarchy
        expect(ordered_terms.first).to eq(term_low)
        expect(ordered_terms.second).to eq(term_mid)
        expect(ordered_terms.third).to eq(term_high)
      end

      it 'includes all terms with hierarchy levels' do
        expect(An::Term.by_hierarchy).to include(term_low, term_mid, term_high)
      end
    end

    describe ".by_body_type" do
      let(:search_body_type) { "CONFPT" }
      let(:body_type) { create(:an_body_type, code: existing_type) }
      let(:body) { create(:an_body, an_body_type: body_type) }
      let!(:term) { create(:an_term, an_body: body) }

      context "when searched body_type exists" do
        let(:existing_type) { search_body_type }

        it { expect(described_class.by_body_type(search_body_type)).to include(term) }
      end

      context "when searched body_type doesn't exist" do
        let(:existing_type) { "UNKNOWN" }

        it { expect(described_class.by_body_type(search_body_type)).not_to include(term) }
      end
    end
  end

  describe 'validations' do
    subject { create(:an_term) }

    it { should validate_presence_of(:uid) }
    it { should validate_uniqueness_of(:uid) }
    it { should validate_presence_of(:an_stakeholder_id) }
    it { should validate_presence_of(:an_body_id) }
    it { should validate_length_of(:label).is_at_most(800) }
  end

  describe '#role_rank_label' do
    let(:term) { build(:an_term) }

    it 'returns very high for rank 1' do
      term.role_rank = 1
      expect(term.role_rank_label).to eq(I18n.t('an.term.role_rank.very_high'))
    end

    it 'returns high for ranks 2-4' do
      term.role_rank = rand(2..4)
      expect(term.role_rank_label).to eq(I18n.t('an.term.role_rank.high'))
    end

    it 'returns medium for ranks 5-30' do
      term.role_rank = rand(5..30)
      expect(term.role_rank_label).to eq(I18n.t('an.term.role_rank.medium'))
    end

    it 'returns low for ranks above 30' do
      term.role_rank = rand(31..100)
      expect(term.role_rank_label).to eq(I18n.t('an.term.role_rank.low'))
    end

    it 'returns low for nil rank' do
      term.role_rank = nil
      expect(term.role_rank_label).to eq(I18n.t('an.term.role_rank.low'))
    end
  end

  describe 'event tracking' do
    describe 'on create' do
      let(:stakeholder) { create(:an_stakeholder) }
      let(:body) { create(:an_body) }
      let(:term) { build(:an_term, an_stakeholder: stakeholder, an_body: body) }

      it 'tracks a created event after commit' do
        expect { term.save! }.to change { term.events.where(action: 'created').count }.by(1)

        event = term.events.find_by(action: 'created')
        expect(event.category).to eq('data')
        expect(event.payload).to include('uid' => term.uid)
      end
    end

    describe 'on update' do
      let!(:term) { create(:an_term, label: 'Old Label') }

      it 'tracks an updated event after commit when changes are saved' do
        expect { term.update!(label: 'New Label') }.to change { term.events.where(action: 'updated').count }.by(1)

        event = term.events.find_by(action: 'updated')
        expect(event.category).to eq('data')
        expect(event.payload).to include('uid' => term.uid)
        expect(event.payload['changes']).to include('label')
      end

      it 'does not track an event when no changes are made' do
        expect { term.save! }.not_to change { term.events.where(action: 'updated').count }
      end
    end
  end
end
