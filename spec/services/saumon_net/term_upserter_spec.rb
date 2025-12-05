require 'rails_helper'

RSpec.describe SaumonNet::TermUpserter do
  let(:stakeholder) { create(:an_stakeholder, gender: 'male') }
  let(:session_id) { 'test-session-id' }

  # Common test values
  let(:term_uid) { "TERM123" }
  let(:body_uid) { "PO123456" }
  let(:legislature) { "16" }
  let(:constituency_uid) { "CIRC01" }
  let(:deputy_term_uid) { "DEPUTY_TERM" }
  let(:start_date) { "2022-06-22" }
  let(:assumption_date) { "2022-06-28" }
  let(:capacity_code) { "Député" }
  let(:capacity_value) { "député" }
  let(:origin_value) { "élection" }
  let(:end_reason_value) { "Fin de législature" }
  let(:seat_value) { "A123" }

  let!(:body) { create(:an_body, uid: body_uid, label_code: "Assemblée nationale") }

  let(:mandate_data) do
    {
      "uid" => term_uid,
      "organes" => { "organeRef" => body_uid },
      "legislature" => legislature,
      "dateDebut" => start_date,
      "dateFin" => nil,
      "datePublication" => "2022-06-23",
      "preseance" => "10",
      "nominPrincipale" => "1",
      "infosQualite" => {
        "codeQualite" => capacity_code
      }
    }
  end

  before do
    allow(An::CorrectionApplier).to receive_message_chain(:new, :detect_all, :apply)
  end

  describe '#upsert ' do
    let(:data) { mandate_data }
    subject(:upserter) { described_class.new(stakeholder, data, session_id) }

    context 'when term does not exist' do
      it 'creates a new term' do
        expect { upserter.upsert }.to change(An::Term, :count).by(1)

        term = An::Term.find_by_uid(term_uid)
        expect(term.an_stakeholder).to eq(stakeholder)
        expect(term.an_body).to eq(body)
        expect(term.legislature).to eq(legislature)
        expect(term.main).to be true
        expect(term.capacity).to eq(capacity_value.parameterize(separator: "_").underscore)
      end
    end

    context 'when term already exists' do
      let!(:existing_term) do
        create(:an_term,
          uid: term_uid,
          an_stakeholder: stakeholder,
          legislature: "15"
        )
      end

      it 'updates the existing term' do
        expect { upserter.upsert }.not_to change(An::Term, :count)

        existing_term.reload
        expect(existing_term.legislature).to eq(legislature)
      end
    end

    context 'with parliamentary mandate' do
      let!(:constituency) { create(:an_body, uid: constituency_uid, label: "1ère circonscription") }
      let(:parliamentary_mandate_data) do
        mandate_data.merge(
          "@xsi:type" => "MandatParlementaire_type",
          "election" => {
            "refCirconscription" => constituency_uid,
            "causeMandat" => origin_value
          },
          "mandature" => {
            "datePriseFonction" => assumption_date,
            "causeFin" => end_reason_value,
            "placeHemicycle" => seat_value
          }
        )
      end
      let(:data) { parliamentary_mandate_data }

      it 'sets constituency and parliamentary attributes' do
        upserter.upsert

        term = An::Term.find_by_uid(term_uid)
        expect(term.constituency).to eq(constituency)
        expect(term.origin).to eq(origin_value)
        expect(term.end_reason).to eq(end_reason_value)
        expect(term.seat).to eq(seat_value)
        expect(term.assumption_date).to be_present
      end

      context 'with mandatRemplaceRef' do
        let!(:deputy_term) { create(:an_term, uid: deputy_term_uid) }

        before do
          parliamentary_mandate_data["mandature"]["mandatRemplaceRef"] = deputy_term_uid
        end

        it 'associates the replaced deputy term' do
          upserter.upsert

          term = An::Term.find_by_uid(term_uid)
          expect(term.deputy_term).to eq(deputy_term)
        end
      end

      context 'without mandatRemplaceRef' do
        it 'sets deputy_term to nil' do
          upserter.upsert

          term = An::Term.find_by_uid(term_uid)
          expect(term.deputy_term).to be_nil
        end
      end
    end

    context 'capacity extraction' do
      it 'parameterizes and underscores the capacity code' do
        upserter.upsert

        term = An::Term.find_by_uid(term_uid)
        expect(term.capacity).to eq("depute")
      end
    end

    context 'label building' do
      it 'builds label from capacity, body, and constituency' do
        allow(An::Term).to receive(:humanize).with("capacities.depute.label", default: nil, gender: 'male').and_return(capacity_code)

        upserter.upsert

        term = An::Term.find_by_uid(term_uid)
        expect(term.label).to include("Assemblée nationale")
        expect(term.label).to include(capacity_code)
      end
    end

    context 'correction application' do
      it 'applies corrections to newly created terms' do
        correction_applier = double('correction_applier')
        allow(An::CorrectionApplier).to receive(:new).and_return(correction_applier)
        allow(correction_applier).to receive(:detect_all).and_return(correction_applier)
        allow(correction_applier).to receive(:apply)

        upserter.upsert

        expect(An::CorrectionApplier).to have_received(:new).with(
          an_instance_of(An::Term),
          session_id: session_id
        )
        expect(correction_applier).to have_received(:detect_all)
        expect(correction_applier).to have_received(:apply)
      end
    end
  end
end
