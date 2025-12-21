require "rails_helper"

RSpec.describe DateFilterable do
  let(:model_class) { An::Term }

  describe ".parse_date_period" do
    context "with year only" do
      it "returns start and end of year" do
        result = model_class.parse_date_period("2024")

        expect(result[:start]).to eq(Date.new(2024, 1, 1))
        expect(result[:end]).to eq(Date.new(2024, 12, 31))
      end
    end

    context "with year-month" do
      it "returns start and end of month" do
        result = model_class.parse_date_period("2024-06")

        expect(result[:start]).to eq(Date.new(2024, 6, 1))
        expect(result[:end]).to eq(Date.new(2024, 6, 30))
      end

      it "handles February correctly" do
        result = model_class.parse_date_period("2024-02")

        expect(result[:start]).to eq(Date.new(2024, 2, 1))
        expect(result[:end]).to eq(Date.new(2024, 2, 29)) # Leap year
      end

      it "handles single-digit month" do
        result = model_class.parse_date_period("2024-6")

        expect(result[:start]).to eq(Date.new(2024, 6, 1))
        expect(result[:end]).to eq(Date.new(2024, 6, 30))
      end
    end

    context "with full date" do
      it "returns same date for start and end" do
        result = model_class.parse_date_period("2024-06-15")

        expect(result[:start]).to eq(Date.new(2024, 6, 15))
        expect(result[:end]).to eq(Date.new(2024, 6, 15))
      end
    end
  end

  describe "scopes" do
    let(:stakeholder) { create(:an_stakeholder) }
    let(:body) { create(:an_body) }

    # Term that was active in 2023 only
    let!(:term_2023) do
      create(:an_term,
             an_stakeholder: stakeholder,
             an_body: body,
             start_date: Date.new(2023, 3, 1),
             end_date: Date.new(2023, 12, 31))
    end

    # Term that was active from 2023 to 2024
    let!(:term_2023_2024) do
      create(:an_term,
             an_stakeholder: stakeholder,
             an_body: body,
             start_date: Date.new(2023, 6, 1),
             end_date: Date.new(2024, 6, 30))
    end

    # Term that started in 2024 and is still active (no end_date)
    let!(:term_current) do
      create(:an_term,
             an_stakeholder: stakeholder,
             an_body: body,
             start_date: Date.new(2024, 1, 1),
             end_date: nil)
    end

    let!(:term_ongoing_year) do
      create(:an_term,
             an_stakeholder: stakeholder,
             an_body: body,
             start_date: Date.new(Date.current.year, 1, 1),
             end_date: nil)
    end

    describe '.active' do
      let!(:active_term) { create(:an_term, start_date: 1.month.ago, end_date: nil) }
      let!(:ended_term) { create(:an_term, start_date: 1.month.ago, end_date: 1.week.ago) }
      let!(:future_term) { create(:an_term, start_date: nil, end_date: nil) }

      it 'returns records with start_date and no end_date' do
        expect(model_class.active).to include(term_current, term_ongoing_year)
        expect(model_class.active).not_to include(term_2023, term_2023_2024)
      end
    end

    describe '.past' do
      it 'returns records with a start and end dates' do
        expect(model_class.past).to include(term_2023, term_2023_2024)
      end
    end

    describe ".date_eq" do
      context "with year only" do
        it "returns terms that were active at any point during the year" do
          results = model_class.date_eq("2024")

          expect(results).to include(term_2023_2024, term_current)
          expect(results).not_to include(term_2023, term_ongoing_year)
        end

        it "returns terms active in 2023" do
          results = model_class.date_eq("2023")

          expect(results).to include(term_2023, term_2023_2024)
          expect(results).not_to include(term_current, term_ongoing_year)
        end
      end

      context "with year-month" do
        it "returns terms active during the month" do
          results = model_class.date_eq("2023-06")

          expect(results).to include(term_2023, term_2023_2024)
          expect(results).not_to include(term_current, term_ongoing_year)
        end

        it "returns terms active in January 2024" do
          results = model_class.date_eq("2024-01")

          expect(results).to include(term_2023_2024, term_current)
          expect(results).not_to include(term_2023, term_ongoing_year)
        end
      end

      context "with full date" do
        it "returns terms active on specific date" do
          results = model_class.date_eq("2024-06-15")

          expect(results).to include(term_2023_2024, term_current)
          expect(results).not_to include(term_2023, term_ongoing_year)
        end
      end
    end

    describe ".date_before" do
      it "returns terms that ended before the given date" do
        results = model_class.date_before("2024-01-01")

        expect(results).to include(term_2023)
        expect(results).not_to include(term_2023_2024, term_current, term_ongoing_year)
      end

      it "excludes terms without an end_date" do
        results = model_class.date_before("2030-01-01")

        expect(results).to include(term_2023, term_2023_2024)
        expect(results).not_to include(term_current, term_ongoing_year)
      end

      it "accepts Date objects" do
        results = model_class.date_before(Date.new(2024, 1, 1))

        expect(results).to include(term_2023)
      end
    end

    describe ".date_after" do
      it "returns terms that started after the given date" do
        results = model_class.date_after("2024-06-01")

        expect(results).to include(term_ongoing_year)
        expect(results).not_to include(term_2023, term_2023_2024, term_current)
      end

      it "returns terms that started after 2023" do
        results = model_class.date_after("2023-12-31")

        expect(results).to include(term_current, term_ongoing_year)
        expect(results).not_to include(term_2023, term_2023_2024)
      end

      it "accepts Date objects" do
        results = model_class.date_after(Date.new(2024, 12, 31))

        expect(results).to include(term_ongoing_year)
      end
    end

    describe ".date_between" do
      it "returns terms active at any point within the range" do
        results = model_class.date_between("2024-01-01", "2024-12-31")

        expect(results).to include(term_2023_2024, term_current)
        expect(results).not_to include(term_2023, term_ongoing_year)
      end

      it "includes terms that overlap with the range" do
        results = model_class.date_between("2023-01-01", "2023-06-30")

        expect(results).to include(term_2023, term_2023_2024)
        expect(results).not_to include(term_current, term_ongoing_year)
      end

      it "includes terms with no end_date if they started before range end" do
        results = model_class.date_between("2020-01-01", "2024-06-30")

        expect(results).to include(term_2023, term_2023_2024, term_current)
        expect(results).not_to include(term_ongoing_year)
      end

      it "accepts Date objects" do
        results = model_class.date_between(Date.new(2024, 1, 1), Date.new(2024, 12, 31))

        expect(results).to include(term_2023_2024, term_current)
      end
    end
  end

  describe "integration with An::Body" do
    let(:body_type) { create(:an_body_type) }

    let!(:active_body) do
      create(:an_body,
             an_body_type: body_type,
             start_date: Date.new(2020, 1, 1),
             end_date: nil)
    end

    let!(:past_body) do
      create(:an_body,
             an_body_type: body_type,
             start_date: Date.new(2019, 1, 1),
             end_date: Date.new(2020, 12, 31))
    end

    it "works with An::Body model" do
      results = An::Body.date_eq("2020")

      expect(results).to include(active_body, past_body)
    end

    it "filters bodies that ended before a date" do
      results = An::Body.date_before("2022-01-01")

      expect(results).to include(past_body)
      expect(results).not_to include(active_body)
    end
  end
end
