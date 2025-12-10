require 'rails_helper'

RSpec.describe An::Stakeholder::SearchContentBuilder, type: :model do
  let(:stakeholder) { create(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont', occupation: 'Avocat') }
  let(:body_type) { create(:an_body_type, hierarchy_level: 1) }
  let(:body) { create(:an_body, an_body_type: body_type) }
  let(:label_text) { 'Député de Paris' }

  shared_examples 'lexical content tests' do |method_name|
    it 'includes name' do
      expect(stakeholder.send(method_name)).to include('jean dupont')
    end

    it 'includes current position label' do
      expect(stakeholder.send(method_name)).to include(label_text)
    end

    it 'includes occupation' do
      expect(stakeholder.send(method_name)).to include('avocat')
    end
  end

  describe '#fts_search_content' do
    let!(:current_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, an_body: body, label: label_text, start_date: 1.month.ago, end_date: nil) }

    include_examples 'lexical content tests', :fts_search_content
  end

  describe '#trigram_search_content' do
    let!(:current_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, an_body: body, label: label_text, start_date: 1.month.ago, end_date: nil) }

    include_examples 'lexical content tests', :trigram_search_content
  end

  describe '#vector_search_content' do
    shared_examples 'vector content tests' do
      it 'includes name' do
        expect(stakeholder.vector_search_content).to include('Jean Dupont')
      end

      it 'includes current position label' do
        expect(stakeholder.vector_search_content).to include(label_text)
      end
    end

    context 'with active position' do
      let!(:active_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, an_body: body, label: label_text, start_date: 1.month.ago, end_date: nil) }

      include_examples 'vector content tests'
    end

    context 'without active position but with past position' do
      let!(:past_term) { create(:an_term, :major_responsibility, an_stakeholder: stakeholder, an_body: body, label: label_text, start_date: 2.years.ago, end_date: 1.year.ago) }

      include_examples 'vector content tests'
    end
  end
end
