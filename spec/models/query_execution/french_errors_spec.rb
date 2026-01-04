# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryExecution::FrenchErrors do
  describe ".for" do
    it "returns the correct message for known error types" do
      expect(described_class.for(:timeout)).to include("trop de temps")
      expect(described_class.for(:model_not_found)).to include("pas disponible")
      expect(described_class.for(:invalid_action)).to include("pas support")
      expect(described_class.for(:no_results)).to include("Aucun")
      expect(described_class.for(:dependency_failed)).to include("tape pr")
      expect(described_class.for(:invalid_date)).to include("date")
      expect(described_class.for(:database_error)).to include("erreur")
    end

    it "interpolates parameters" do
      message = described_class.for(:ambiguous_query, suggestions: "option A, option B")

      expect(message).to include("option A, option B")
    end

    it "returns unknown error message for invalid error types" do
      expect(described_class.for(:nonexistent_error)).to include("inattendue")
    end

    it "handles missing interpolation keys gracefully" do
      # When no params are passed, the raw message with placeholder is returned
      message = described_class.for(:ambiguous_query)
      expect(message).to include("ambigu")
    end
  end

  describe ".available_error_types" do
    it "returns all defined error types" do
      types = described_class.available_error_types

      expect(types).to include(:timeout)
      expect(types).to include(:model_not_found)
      expect(types).to include(:invalid_action)
    end
  end
end
