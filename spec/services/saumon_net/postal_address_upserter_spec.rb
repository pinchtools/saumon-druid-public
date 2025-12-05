require 'rails_helper'

RSpec.describe SaumonNet::PostalAddressUpserter do
  let(:stakeholder) { create(:an_stakeholder) }
  let(:logger) { double('logger', debug: nil) }
  let(:session_id) { 'test-session-id' }
  subject(:upserter) { described_class.new(stakeholder, address_data, session_id) }

  before do
    allow(upserter).to receive(:logger).and_return(logger)
  end

  let(:address_uid) { "ADR123" }
  let(:address_type) { "0" }
  let(:address_label) { "Bureau de circonscription" }
  let(:address_complement) { "Bâtiment A" }
  let(:street_number) { "123" }
  let(:street_name) { "Rue de la République" }
  let(:post_code) { "75001" }
  let(:city) { "Paris" }
  let(:weight) { "1" }
  let(:existing_city) { "Lyon" }
  let(:invalid_type) { "999" }

  let(:address_data) do
    {
      "uid" => address_uid,
      "type" => address_type,
      "intitule" => address_label,
      "complementAdresse" => address_complement,
      "numeroRue" => street_number,
      "nomRue" => street_name,
      "codePostal" => post_code,
      "ville" => city,
      "poids" => weight
    }
  end

  describe '#upsert' do
    context 'when address does not exist' do
      it 'creates a new address' do
        expect {
          upserter.upsert
        }.to change(An::StakeholderAddress, :count).by(1)

        address = An::StakeholderAddress.last
        expect(address.uid).to eq(address_uid)
        expect(address.address_1).to eq(address_label)
        expect(address.address_2).to eq(address_complement)
        expect(address.street_number).to eq(street_number)
        expect(address.street_name).to eq(street_name)
        expect(address.post_code).to eq(post_code)
        expect(address.city).to eq(city)
        expect(address.weight).to eq(weight.to_i)
        expect(address.an_stakeholder).to eq(stakeholder)
      end

      it 'logs creation' do
        upserter.upsert

        expect(logger).to have_received(:debug).with(hash_including(
          message: "Address created",
          address_uid: address_uid
        ))
      end
    end

    context 'when address already exists' do
      let!(:existing_address) do
        create(:an_stakeholder_address,
          uid: address_uid,
          an_stakeholder: stakeholder,
          city: existing_city
        )
      end

      it 'updates the existing address' do
        expect {
          upserter.upsert
        }.not_to change(An::StakeholderAddress, :count)

        existing_address.reload
        expect(existing_address.city).to eq(city)
      end

      it 'logs update' do
        upserter.upsert

        expect(logger).to have_received(:debug).with(hash_including(
          message: "Address updated",
          address_uid: address_uid
        ))
      end
    end

    context 'address type mapping' do
      it 'maps type 0 correctly' do
        upserter.upsert

        address = An::StakeholderAddress.last
        expect(address.address_type).to eq(An::StakeholderAddress::ADDRESS_TYPES[0])
      end

      context 'when type is invalid' do
        let(:address_data) { super().merge("type" => invalid_type) }

        it 'defaults to "other" for invalid type index' do
          upserter.upsert

          address = An::StakeholderAddress.last
          expect(address.address_type).to eq("other")
        end
      end
    end

    context 'when UID is missing' do
      let(:address_data) { super().except("uid") }
      it 'returns early without creating address' do
        expect {
          upserter.upsert
        }.not_to change(An::StakeholderAddress, :count)
      end
    end
  end
end
